local dog = workspace:FindFirstChild("dogMalus", true)
if dog then
	print("Dog found: " .. dog:GetFullName())
	print("Anchored parts:")
	for _, p in dog:GetDescendants() do
		if p:IsA("BasePart") then
			print("  " .. p.Name .. " Anchored: " .. tostring(p.Anchored))
		end
	end
	print("Welds:")
	for _, w in dog:GetDescendants() do
		if w:IsA("Weld") or w:IsA("WeldConstraint") or w:IsA("Motor6D") then
			print("  " .. w.Name .. " (" .. w.ClassName .. ") Parent: " .. w.Parent.Name .. " P0: " .. (w.Part0 and w.Part0.Name or "nil") .. " P1: " .. (w.Part1 and w.Part1.Name or "nil"))
		end
	end
else
	print("Dog not found")
end
