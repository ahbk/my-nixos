local ok, mymod = pcall(require, 'init')
if ok then
	print(mymod)
else
	print(ok)
end
