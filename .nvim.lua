vim.cmd.compiler("vcs")
vim.o.makeprg = [[ssh vlsi 'cd $HOME/src/ee5327/ee5327-mpeg4me && pwd && make $*']]
vim.bo.makeprg = vim.o.makeprg
