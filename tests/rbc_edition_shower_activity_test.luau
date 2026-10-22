local state={}
local reportStatus
reportStatus = function(laststatus, lastfield)
		if laststatus then state.activityStatus = laststatus end
end
reportStatus(1)
assert(state.activityStatus==1,"gathering must enable shower gate without dashboard")
reportStatus(nil)
assert(state.activityStatus==1,"field-only report must preserve activity")
reportStatus(2)
assert(state.activityStatus==2,"travel must disable gathering shower gate")
print("PASS: gathering activity updates independently of graph/dashboard")
