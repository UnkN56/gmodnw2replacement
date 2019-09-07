module("NW3",package.seeall)
if true then return end
Storage=Storage or {}
Queue=Queue or {}
Types={"Angle","Bool","Entity","Float","String","Vector"}
local tcount=#Types
local defs={Angle(0,0,0),false,NULL,0.00,"",Vector(0,0,0)}
local entmeta=FindMetaTable("Entity")
if SERVER then
	util.AddNetworkString("NW3")
	OQueue=OQueue or {}
	function QueueNWVar(ent,t,var,val)
		local was=ent._NW3[var]
		if was==val then return end
		if Queue[ent] == nil then
			Queue[ent]={}
		end
		Queue[ent][#Queue[ent]+1]={t,var,val}
		NWChanged(ent,var,was,val)
	end
	local next,pairs,IsValid=next,pairs,IsValid
	hook.Add("Tick","NW3",function()
		local i,m=next(Queue)
		if i==nil then
			i,m=next(OQueue)
			if i==nil then
				return
			else
				OQueue[i]=nil
				--if IsValid(m[1]) and IsValid(m[2]) then
				net.Start("NW3")
				net.WriteUInt(m[2]:EntIndex(),16)
				for q=1,tcount do
					local nm=Types[q]
					for k,v in pairs(m[3][q]) do
						net.WriteUInt(q,3)
						net.WriteString(k)
						net["Write"..nm](v)
					end
				end
				net.WriteUInt(0,3)
				net.Send(m[1])
			end
		else
			Queue[i]=nil
			net.Start("NW3")
			net.WriteUInt(i:EntIndex(),16)
			for _,v in pairs(m) do
				net.WriteUInt(v[1],3)
				net.WriteString(v[2])
				local nm=Types[v[1]]
				net["Write"..nm](v[3])
			end
			net.WriteUInt(0,3)
			net.Broadcast()
		end
	end)
	hook.Add("PlayerInitialSpawn","NW3",function(ply)
		for k,v in pairs(Storage) do
			if Queue[k] == nil then
				OQueue[#OQueue+1]={ply,k,v}
			end
		end
	end)
	hook.Add("PlayerDisconnected","NW3",function(ply)
		for k,v in pairs(OQueue) do
			if v[1]==ply then
				OQueue[k]=nil
			end
		end
	end)
	hook.Add("EntityRemoved","NW3",function(ent)
		if Storage[ent] then
			Storage[ent]=nil
			net.Start("NW3")
			net.WriteUInt(ent:EntIndex(),16)
			net.WriteUInt(7,3)
			net.Broadcast()
		end
	end)
else
	function QueueNWVar(ent,t,var,val)
		--NWChanged(ent,var,ent._NW3[var],val)
	end
	net.Receive("NW3",function(len)
		local ent,tab,set=net.ReadUInt(16),nil,false
		local e=Entity(ent)
		if IsValid(e) then
			if e._NW3==nil then
				InitStorage(e)
			end
			tab=e._NW3
			set=true
		else
			if Queue[ent] == nil then
				Queue[ent] = {}
				for i=1,tcount do
					Queue[ent][i]={}
				end
			end
			tab=Queue[ent]
		end
		for i=1,1024 do
			local t=net.ReadUInt(3)
			if t==0 then break end
			if t==7 then
				if Queue[ent] then
					Queue[ent]=nil
				end
				return
			end
			--if not Types[t] then continue end
			local var,val=net.ReadString(),net["Read"..Types[t]]()
			if set then
				NWChanged(e,var,tab[var],val)
			end
			tab[t][var]=val
		end
	end)
	hook.Add("NotifyShouldTransmit","NW3",function(e,b)
		local uid=e:EntIndex()
		if Queue[uid] then
			e._NW3=Queue[uid]
			Queue[uid]=nil
			for i=1,tcount do
				for k,v in pairs(e._NW3[i]) do
					NWChanged(e,k,nil,v,i)
				end
			end
			Storage[e]=e._NW3
		end
	end)
	hook.Add("EntityRemoved","NW3",function(ent)
		if Storage[ent] then
			Storage[ent]=nil
		end
	end)
end
function InitStorage(ent)
	ent._NW3={}
	for i=1,#Types do
		ent._NW3[i]={}
	end
	Storage[ent]=ent._NW3
end
function NWChanged(ent,key,old,new,type)
	hook.Run("EntityNetworkedVarChanged",ent,key,old,new,type)
end
for i=1,tcount do
	local v=Types[i]
	entmeta["SetNW3"..v]=function(self,var,val)
		if self._NW3 == nil then
			InitStorage(self)
		end
		QueueNWVar(self,i,var,val)
		self._NW3[i][var]=val
	end
	entmeta["GetNW3"..v]=function(self,var)
		if self._NW3 == nil then
			return defs[i]
		end
		return self._NW3[i][var] or defs[i]
	end
end
function entmeta:SetNW3Int(var,val)
	self:SetNW3Float(var,math.Round(val))
end
function entmeta:GetNW3Int(var)
	return math.Round(self:GetNW3Float(var))
end
local r=table.Copy(Types)
table.insert(r,"Int")
function ReplaceNW(s)
	for i=1,#r do
		local v=r[i]
		entmeta["SetNW"..s..v]=entmeta["SetNW3"..v]
		entmeta["GetNW"..s..v]=entmeta["GetNW3"..v]
	end
end
--ReplaceNW("")
ReplaceNW("2")