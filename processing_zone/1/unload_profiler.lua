-- Unload all packages
for k in pairs(package.loaded) do
	package.loaded[k] = nil
end
