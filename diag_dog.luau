local Workspace = game:GetService("Workspace")

print("--- DIAGNOSTIC START ---")
local found = false
for _, obj in Workspace:GetDescendants() do
	if obj.Name:lower():match("dog") then
		print("FOUND DOG OBJECT: " .. obj:GetFullName() .. " (" .. obj.ClassName .. ")")
		if obj:IsA("Model") then
			local hum = obj:FindFirstChildOfClass("Humanoid")
			print(" -> Has Humanoid: " .. tostring(hum ~= nil))
			if hum then print(" -> Humanoid Parent: " .. hum.Parent:GetFullName()) end
			local rp = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart")
			print(" -> Has PrimaryPart/HRP: " .. tostring(rp ~= nil))
		end
		found = true
	end
end
if not found then print("NO 'DOG' OBJECTS FOUND IN WORKSPACE") end

print("Checking Braces:")
for _, obj in Workspace:GetDescendants() do
	if obj:IsA("Model") and obj.Name:lower():match("brace") then
		print("FOUND BRACE: " .. obj:GetFullName())
		for k, v in pairs(obj:GetAttributes()) do
			print(" -> Attr: " .. k .. " = " .. tostring(v))
		end
	end
end
print("--- DIAGNOSTIC END ---")
