local dog = workspace:FindFirstChild("dogMalus", true)
if dog then
	print("DOG STRUCTURE:")
	local function printHierarchy(obj, indent)
		print(string.rep("  ", indent) .. obj.Name .. " (" .. obj.ClassName .. ")")
		for _, child in obj:GetChildren() do
			printHierarchy(child, indent + 1)
		end
	end
	printHierarchy(dog, 0)
	
	print("\nJOINTS/WELDS INFO:")
	for _, v in dog:GetDescendants() do
		if v:IsA("JointInstance") or v:IsA("WeldConstraint") then
			local p0 = v:IsA("WeldConstraint") and v.Part0 or v.Part0
			local p1 = v:IsA("WeldConstraint") and v.Part1 or v.Part1
			print("  " .. v.Name .. " (" .. v.ClassName .. ") | P0: " .. (p0 and p0.Name or "nil") .. " | P1: " .. (p1 and p1.Name or "nil") .. " | Parent: " .. v.Parent.Name)
		end
	end
	
	local humanoid = dog:FindFirstChildOfClass("Humanoid") or dog:FindFirstChild("Humanoid", true)
	print("\nHUMANOID FOUND: " .. tostring(humanoid ~= nil))
else
	print("DOG NOT FOUND")
end
