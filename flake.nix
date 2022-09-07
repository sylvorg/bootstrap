{
    description = "Ooh, shiny!";
    inputs = rec {
        settings.url = github:sylvorg/settings;
        titan.url = github:syvlorg/titan;
        flake-utils.url = github:numtide/flake-utils;
        py3pkg-bakery.url = github:syvlorg/bakery;
        py3pkg-tailapi.url = github:syvlorg/tailapi;
        py3pkg-pytest-hy.url = github:syvlorg/pytest-hy;
        flake-compat = {
            url = "github:edolstra/flake-compat";
            flake = false;
        };
    };
    outputs = inputs@{ self, flake-utils, settings, ... }: with builtins; with settings.lib; with flake-utils.lib; settings.mkOutputs {
        inherit inputs;
        type = "hy";
        pname = "bootstrap";
        isApp = true;
        callPackage = args@{ stdenv, pname, bakery, tailapi }: j.mkPythonPackage self stdenv [ "postCheck" ] (rec {
            doCheck = false;
            owner = "sylvorg";
            inherit pname;
            src = ./.;
            propagatedBuildInputs = [ bakery tailapi ];
            postPatch = ''
                substituteInPlace pyproject.toml --replace "bakery = { git = \"https://github.com/syvlorg/bakery.git\", branch = \"main\" }" ""
                substituteInPlace setup.py --replace "'bakery @ git+https://github.com/syvlorg/bakery.git@main'," "" || :
                substituteInPlace pyproject.toml --replace "tailapi = { git = \"https://github.com/syvlorg/tailapi.git\", branch = \"main\" }" ""
                substituteInPlace setup.py --replace "'tailapi @ git+https://github.com/syvlorg/tailapi.git@main'," "" || :
            '';
            meta.description = "Ooh, shiny!";
        });
    };
}
