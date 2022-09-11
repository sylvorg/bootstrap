(import rich.traceback)
(.install rich.traceback :show-locals True)

(import bakery)
(import oreo)
(import socket)
(import stat)

(eval-and-compile (import os hy))

(import bakery [chown echo gpg git make scp systemctl uname yadm zfs])
(import os [path listdir chmod getlogin symlink])
(import pathlib [Path])
(import requests.auth [HTTPBasicAuth])
(import shutil [which])
(import tailapi [Keys])
(import uuid [uuid4 uuid5])

(try (import coconut *)
     (except [ImportError] None))

(try (import cytoolz [first])
     (except [ImportError]
             (import toolz [first])))

(require hyrule [-> assoc unless])

(import click)

(setv operating-system (uname :o True :m/str True)
      on-Android (= operating-system "Android")
      gpg-one-req [ "private-gpg-key" "scp-gpg-key" "import-yubikey" ])

(defn yes? [ var ] (in (.lower var) #("y" "yes")))
(defn dyes? [ var default ] (if (yes? var) default var))
(defn iyes? [ query ] (yes? (input query)))
(defn no? [ var ] (if (in (.lower var) #("n" "no")) False var))

(defn chmod-bootstrap [ bootstrap ] (.chmod bootstrap (| (| (| (.stat bootstrap) (.S_IEXEC stat)) (.S_IXGRP stat)) (.S_IXOTH stat))))

(unless on-Android (import bakery [tailscale nixos-generate-config]))

(defn [ (.command click)
        (.argument click "tags")
        (.option click "--print" :help "Print bakery commands and run them")
        (.option click "-A" "--tailscale-api-command" :default "pass show keys/api/tailscale/jeet.ray")
        (.option click "-a" "--tailscale-api-key")
        (.option click "--bootstrap/--dont-bootstrap" :help "Run yadm bootstrap" :default True)
        (.option click "-c" "--current-user-primary-user" :is-flag True)
        (.option click "-e" "--ephemeral" :is-flag True :help "Set the ephemeral property for a new tailscale authkey")
        (.option click "-g" "--gpg-key-id" :default "jeet.ray@syvl.org")
        (.option click "--impermanent/--not-impermanent" :help "Root wiped on boot" :default True)
        (.option click "-i" "--initialize-primary-submodules")
        (.option click "-I" "--initialize-yadm-submodules")
        (.option click "-J" "--tailscale-interface" :default (if on-Android "tun0" "tailscale0"))
        (.option click "-o" "--operating-system" :default operating-system)
        (.option click "-p" "--primary-user" :default "shadowrylander")
        (.option click "-P" "--private-gpg-key" :help "Path to private gpg key" :cls oreo.Option :xor [ "scp-gpg-key" "import-yubikey" ] :one-req gpg-one-req)
        (.option click "-R" "--preauthorized" :is-flag True :help "Set the pre-authorized property for a new tailscale authkey")
        (.option click "-r" "--reusable" :is-flag True :help "Set the reusable property for a new tailscale authkey")
        (.option click
                 "-s"
                 "--scp-gpg-key"
                 :cls oreo.Option
                 :xor [ "private-gpg-key" "import-yubikey" ]
                 :one-req gpg-one-req
                 :help #[[SCP the private gpg key from here;
takes three arguments: user@address:path-to-private-gpg-key, the ssh port on the remote end, and the path to store the private gpg key at locally.]]
                 :type #(str int str))
        (.option click "--shared-primary-repo/--individual-primary-repos" :default True)
        (.option click "-T" "--tailscale-domain" :default "sylvorg.github")
        (.option click "--use-tailscale/--dont-use-tailscale" :default (not on-Android))
        (.option click "-u" "--user-repo" :default "/home/shadowrylander/aiern")
        (.option click "--import-yubikey/--dont-import-yubikey" :default True :cls oreo.Option :xor [ "private-gpg-key" "scp-gpg-key" ] :one-req gpg-one-req)
        (.option click "-y" "--yadm-clone" :is-flag True)
        (.option click "--zfs-root/--non-zfs-root" :default True) ]
      main [ bootstrap
             current-user-primary-user
             ephemeral
             gpg-key-id
             impermanent
             import-yubikey
             initialize-primary-submodules
             initialize-yadm-submodules
             operating-system
             preauthorized
             primary-user
             print
             private-gpg-key
             reusable
             scp-gpg-key
             shared-primary-repo
             tailscale-api-command
             tailscale-api-key
             tailscale-domain
             tailscale-interface
             use-tailscale
             user-repo
             yadm-clone
             zfs-root ]
      "TAGS: Tags to set for a new authkey, as a string of tags separated by spaces"
      (let [ home (.home Path)
             bootstrap-path (Path f"{home}/.config/yadm/bootstrap")
             current-user (getlogin)
             worktree (if impermanent f"/persist/{home}" home)
             clone-opts { "w" worktree "no-bootstrap" True }
             hostname (.gethostname socket)
             primary-user (if current-user-primary-user current-user primary-user)
             dataset f"{hostname}/{primary-user}"
             primary-home (Path f"~{primary-user}")
             reponame "aiern"
             primary-repo (Path f"{primary-home}/{reponame}")
             private-gpg-key (if private-gpg-key (Path private-gpg-key) private-gpg-key)
             initialize-primary-submodules (or initialize-primary-submodules (not (.submodule (git :C primary-repo) "foreach" :m/bool True)))
             initialize-yadm-submodules (or initialize-yadm-submodules (not (.submodule yadm "foreach" :m/bool True :m/false-error True)))
             submodule-opts { "m/starter-args" #("update")
                              "m/exports" { "GIT_DISCOVERY_ACROSS_FILESYSTEM" 1 }
                              "m/dazzling" True
                              "init" True
                              "recursive" True
                              "remote" True
                              "force" True }
             tailscale-api-command-split (.split tailscale-api-command)
             tailscale-api-command-args (cut tailscale-api-command-split 1 None)
             tailscale-api-command-bin (bakery (get tailscale-api-command-split 0))
             interfaces (ifconfig :m/split True)
             tailscaled-enabled (when use-tailscale (in f"{tailscale-interface}:" interfaces))
             tailscale-bin (if (or on-Android (not use-tailscale))
                               None
                               (bakery :program- "tailscale"))
             tailscale-authenticated (when use-tailscale
                                           (if on-Android
                                               tailscaled-enabled
                                               (not (= (.status tailscale-bin :m/str True) "Logged out."))))
             tailscale-enabled (when use-tailscale
                                     (if on-Android
                                         tailscaled-enabled
                                         (= (. (.status tailscale-bin :m/verbosity 1) returns code) 0)))
             user-repo (Path user-repo)
             username "shadowrylander"
             yadm-repo (Path f"{home}/.local/share/yadm/repo.git")
             yadm-clone (or yadm-clone (not (.exists yadm-repo)))
             tailapi (Keys :auth (HTTPBasicAuth (or tailscale-api-key (tailscale-api-command-bin #* tailscale-api-command-args)) "")
                           :domain tailscale-domain
                           :recreate-response True) ]
           (.bake-all- gpg :m/print-command-and-run print)
           (when private-gpg-key (.import gpg private-gpg-key))
           (when scp-gpg-key
                 (let [ remote-path (get scp-gpg-key 0)
                        port (get scp-gpg-key 1)
                        gpg-key (Path (get scp-gpg-key 2)) ]
                      (scp :P port :C True :r True :m/run True remote-path gpg-key)
                      (.import gpg gpg-key)))
           (when import-yubikey
                 (for [line (gpg :card-status True :m/split "\n")]
                      (when (in "URL" line)
                            (gpg :fetch (get (.split line ": ") 1))
                            (break))))
           (| (echo (+ (.join "" (.split (get (gpg :fingerprint True gpg-key-id :m/list True) 1))) ":6:")) (gpg :import-ownertrust True))
           (gpg :fingerprint True gpg-key-id :m/run False)
           (when (not (or (.exists path user-repo) (len (listdir user-repo))))
                 (unless shared-primary-repo
                         (.mkdir (Path primary-repo) :parents True :exist-ok True)
                         (when (not (and (= current-user primary-user) (.exists path user-repo))) (symlink primary-repo user-repo)))
                 (.clone git f"https://github.com/{username}/{username}.git" user-repo)
                 (.remote (git :C user-repo) :m/starter-args #("set-url") :push True "origin" f"git@github.com:{username}/{username}.git")

                 ;; If I unlock before I update the submodules, I can use `ssh://' urls immediately
                 (.crypt (git :C user-repo) "unlock")
                 (.submodule (git :C user-repo) :m/regular-args #(".password-store") #** submodule-opts)

                 (when use-tailscale
                       (if tailscaled-enabled
                           (unless tailscale-enabled
                                   (if impermanent
                                       (.up tailscale :hostname (uuid5 (uuid4) (str (uuid4)))
                                                      :authkey (if tailscale-authenticated
                                                                   False
                                                                   (get (.create-key (tailapi :ephemeral True :tags #("bootstrap"))) "key")))
                                       (.up tailscale :hostname hostname
                                                      :authkey (if tailscale-authenticated
                                                                   False
                                                                   (get (.create-key (tailapi :ephemeral ephemeral
                                                                                              :preauthorized preauthorized
                                                                                              :reusable reusable
                                                                                              :tags tags)) "key")))))
                           (raise (ValueError "Sorry; enable the tailscale daemon to continue!"))))
                 (when initialize-primary-submodules
                       (.submodule (git :C user-repo) #** submodule-opts)
                       (for [ m (.submodule yadm :m/starter-args #("foreach") :recursive True :m/list True) ]
                            (.crypt (git :C (+ user-repo "/" (get (.split m "'") 1))) "unlock" :m/ignore-stderr True))
                       (chown :R True f"{primary-user}:{primary-user}" user-repo)))
           (when yadm-clone
                 (.clone yadm :f True #** clone-opts user-repo)
                 (.remote (git :C user-repo) :m/starter-args #("add") current-user yadm-repo)
                 (.crypt yadm unlock)
                 (when initialize-yadm-submodules
                       (when impermanent (.gitconfig yadm "core.worktree" worktree))
                             (.submodule yadm #** submodule-opts)
                             (for [ m (.submodule yadm :m/starter-args #("foreach") :recursive True :m/list True) ]
                                  (.crypt (git :C (+ worktree "/" (get (.split m "'") 1))) "unlock" :m/ignore-stderr True))
                             (.gitconfig yadm "core.worktree" home)
                             (when (which "emacs") (make :f f"{worktree}/.emacs.d/makefile" "soft-init"))))
           (unless on-Android (nixos-generate-config :run True))
           (when bootstrap
                 (chmod-bootstrap bootstrap-path)
                 ((bakery :program- bootstrap-path) worktree))
           (when zfs-root
                 (.set zfs :snapdir "visible" dataset :m/run True)
                 (.inherit zfs :r True "snapdir" dataset :m/run True))))
