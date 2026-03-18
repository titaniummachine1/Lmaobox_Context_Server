local target = debug_currentTarget
if target then
    print("entity", target.entity ~= nil)
    print("angles", target.angles ~= nil)
    print("factor", target.factor ~= nil)
    print("pos", target.pos ~= nil)
else
    print("no exported target")
end
