# opensuse-translation-compendium
Tools for repository translation compendium.

It loads repository metadata, finds, categorizes and concatenates all
translation .mo files into a large per-language translation compendiums.

It is a disk space, network and time hungry tool. It needs ~9 GB data
download, ~18 GB of disk space and ~6 days of single CPU time.

The use is simple: Run it in the current directory, and several day later
you will get compendium files.

It currently supports only mo files, and it ignores any files that cause
errors.

The resulting po file headers are very large, as it concatenate all headers
from particular projects. You probably want to cut them down.
