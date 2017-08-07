Simple Note Store
=================

This is a very simple notes manager based heavily on the excellent
[password store](http://www.passwordstore.org) utility by Jason Donenfeld.

It allows for storage retrieval and editing of text notes inside the note
store directory. If the note store directory is a git repositoy, changes
will be commited automatically.

It can be used as a stand-alone tool or as a backend to the
[notes-visual](https://github.com/phha/notes-visual)
utility.

Please see the man page and [installation instructions](INSTALL.md) for detailed information. 

Depends on:
* bash
  * http://www.gnu.org/software/bash/
* git
  * http://www.git-scm.com/
* tree >= 1.7.0
  * http://mama.indstate.edu/users/ice/tree/
* GNU getopt
  * http://www.kernel.org/pub/linux/utils/util-linux/
  * http://software.frodo.looijaard.name/getopt/

