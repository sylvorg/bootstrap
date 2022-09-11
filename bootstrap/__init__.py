#!/usr/bin/env python3
import rich.traceback as RichTraceback
RichTraceback.install(show_locals = True)

import hy

hy.macros.require('bootstrap.bootstrap',
    # The Python equivalent of `(require bootstrap.bootstrap *)`
    None, assignments = 'ALL', prefix = '')
hy.macros.require_reader('bootstrap.bootstrap', None, assignments = 'ALL')
from bootstrap.bootstrap import *

from addict import Dict

if __name__ == "__main__":
    main(obj=Dict(dict()))
