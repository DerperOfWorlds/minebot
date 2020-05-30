 
--thanks to Ava, QT, and Ghost for paving the way
--to full mine automation
waypoint="minecenter"
range=50
 
local minecore = {}
 
local r = require("robot")
local c = require("component")
local nav = c.navigation
local computer = require("computer")
local invcon = c.inventory_controller
local sides = require("sides")
local geo = c.geolyzer
local rs = c.redstone --redstone card
local ser = require("serialization")
local file = require("filesystem") 
 
local status={}
status.currentDir=nav.getFacing()
status.currentPosition={}
status.currentState=0
--0 recharge at home, 1 mine

--current target status
--status.targetIndex=1 target index is always one
status.targetUpper=0--upper portion of mineshaft
status.targetLower=0--lower portion of mineshaft
--status.targetX={} --list of target x coordinates (which one we go for is based on the status.targetIndex
--status.targetZ={} --               z

--status spiral recreation data, allows bot to constantly generate series of positions
status.spiraldata={}
status.spiraldata.xlast=0
status.spiraldata.zlast=0
status.spiraldata.inc=1
status.spiraldata.dir=0
status.spiraldata.start=1
status.spiraldata.spot=1
status.spiraldata.x={}
status.spiraldata.z={}
status.spiraldata.keys={}
--

--the path of things the bot mines 


--=======================
--    debug functions
--=======================

--print thing to debug console
function debugp(message, update)
  update=update or false
  if update==false then
    print(message)
  else
    x,y=term.getCursor()
    term.setCursor(x,y-1)
    print(message)
  end
end 

 
--=======================
-- [DATA] load and save
--=======================
function saveStatus()
  debugp("[Save] Saving status...")
  local file=io.open("status","w")
  if file==nil then debugp("[Save] Failed to save status",true) return false end
  debugp("[Save] Saved status.", true)
  file:write(ser.serialize(status))
  file:close()
end

function loadStatus()
  debugp("[Load] Loading current status...")
  local file2=io.open("status","r")
  if file2==nil then debugp("[Load] Failed to load status!", true) return false end
  local text=file2:read("*all")
  file2:close()
  status=ser.unserialize(text)
  debugp("[Load] Loaded current status.",true)
  return true
end 
 
--=======================
--basic utility functions
--=======================
 
 
--position generation
--indata: x,y,direction,increment,startkey,spot within inc
function getPositionData(indata,numpositions) --generates spiral
  retdata={}
  retdata.x={}
  retdata.z={}
  retdata.keys={}
  count=0
  local dr=indata.dir
  local xx=indata.xlast
  local zz=indata.zlast
  local incc=indata.inc
  local spotout=indata.spot
  local startkey=indata.start
  debugp("[PosData] Generating position paths... ")
  while count<numpositions do
    for spt=spotout, incc*2 do
      if dr==0 then
        zz=zz+1
      elseif dr==1 then
        xx=xx+1
      elseif dr==2 then
        zz=zz-1
      elseif dr==3 then
        xx=xx-1
      end
      --term.setCursor(xx,zz)
      --term.write(char)
      retdata.x[#(retdata.x)+1]=xx
      retdata.z[#(retdata.z)+1]=zz
      retdata.keys[#(retdata.keys)+1]=startkey+count
      count=count+1
      if spt==incc then dr=dr+1 dr=dr%4 end
      spotout=spt
	  debugp("[PosData] Generating position paths... "..count,true)
    end
    dr=dr+1 dr=dr%4 incc=incc+1 spotout=1
	
  end
  retdata.xlast=xx
  retdata.zlast=zz
  retdata.inc=incc    
  retdata.dir=dr
  retdata.spot=spotout
  retdata.start=startkey+count
  debugp("[PosData] Generated position paths.         ",true)
  return retdata
end
 
 --set waypoint target name
function setWaypoint(wp)
  waypoint=wp
  debugp("[PosData] Set waypoint.")
end
 
function getEnergy()
  curpow=computer.energy()
  maxpow=computer.maxEnergy()
  debugp("[getEnergy] Current energy:"..math.floor((curpow/maxpow)*100).."%")
  return math.floor((curpow/maxpow)*100)
end
 
--recharging utility function
function setRecharge(state)
  if state==true then
	for i=0,5 do
      rs.setOutput(i,15)
    end
	debugp("[Recharge] Charging:ON            ",true)	
  elseif state==false then
    for i=0,5 do
      rs.setOutput(i,0)
    end
	debugp("[Recharge] Charging:OFF             ",true)		
  end
end
 
--try recharging robot 
function updateRecharge()
  debugp("[Recharge] Updating charging... ")
  if(getEnergy()<100) then
    setRecharge(true)
  else
    setRecharge(false)
  end  
end
  
 
--don't use often, very heavy
--(for this potato anyway)
function getWaypoint()
  wp = nav.findWaypoints(range)
  debugp("[Waypoint] Finding waypoint...")
  for i=1,#wp do
    if wp[i].label==waypoint then
	  debugp("[Waypoint] Found waypoint "..wp.label..".",true)
      return wp[i]
    end
  end
  debugp("[Waypoint] Failed to find waypoint!        ",true)
  os.exit()
  return nil --should never happen hpf
end
 
status.position=getWaypoint().position
for i=1,#status.position do
   status.position[i]=status.position[i]*(-1)
end
 
 
--====================
--movement and actions
--====================
function turnRight()
  r.turnRight()
  status.currentDir=nav.getFacing()  --update dir
end
 
function turnLeft()
  r.turnLeft()
  status.currentDir=nav.getFacing()  --update dir
end
 
function forward()
  local suc,rea = r.forward()
  if suc==nil then return false end
  if status.currentDir==2 then --negz
	status.currentDir.position[3]=status.currentDir.position[3]-1
  elseif status.currentDir==3 then --posz
    status.currentDir.position[3]=status.currentDir.position[3]+1
  elseif status.currentDir==4 then --negx
	status.currentDir.position[1]=status.currentDir.position[1]-1  
  elseif status.currentDir==5 then --posx
	status.currentDir.position[1]=status.currentDir.position[1]+1    
  end
  return true
end
 
function back()
  local suc,rea = r.back()
  if suc==nil then return false end
  if status.currentDir==2 then --negz
	status.currentDir.position[3]=status.currentDir.position[3]+1
  elseif status.currentDir==3 then --posz
    status.currentDir.position[3]=status.currentDir.position[3]-1
  elseif status.currentDir==4 then --negx
	status.currentDir.position[1]=status.currentDir.position[1]+1  
  elseif status.currentDir==5 then --posx
	status.currentDir.position[1]=status.currentDir.position[1]-1    
  end  
  return true
end
 
function up()
  local suc,rea = r.up()
  if suc==nil then return false end
  status.position[2]=status.position[2]+1
  return true  
end
 
function down()
  local suc,rea = r.down()
  if suc==nil then return false end
  status.position[2]=status.position[2]-1
  return true  
end
 
function mine(side)
  side=side or 5 --random side that isn't important means just mine forward
  local suc
  local rea
  if side==sides.up then
    suc,rea=r.swingUp()
  elseif side==sides.down then
    suc,rea=r.swingDown()
  else
    suc,rea=r.swing()
  end
  return suc,rea
end
 
 
 
--====================
--higher level movement
--==================== 
 
dirmap = {-1,2,0,1,3} --converts normal directions to internal directions
edirmap = {3,4,2,5,3,4,2,5,3,4,2,5} --converts back to normal directions ADD ONE TO INTERNAL DIRECTION BEFORE CONVERT
--turns to WORLD direction
function turnToDir(targDir)
  if targDir==sides.up or targDir==sides.down then
    do return end --don't turn to up, not possible
  end
  curDir=nav.getFacing()
  if curDir==targDir then do return end end
  cDir=dirmap[curDir]
  tDir=dirmap[targDir]
--  print("target direction "..targDir.." -> "..tDir)
--  print("current direction "..curDir.." -> "..cDir)
  dirInd=tDir-cDir
  dirInd=dirInd%4
  dirInd=dirInd-1.5
--  print("Turning From "..cDir.." to "..tDir)
  if tDir==-1 or cDir==-1 then print("ERROR") end
  --if (tDir==3 and cDir==0) or (tDir==0 and cDir==3) then
  --  dirInd=dirInd*-1
  --end
  amnt=1
  if(math.abs(tDir-cDir)==2) then amnt=2 end
  if dirInd<0 then
    for i=1,amnt do
      turnRight()
    end  
  elseif dirInd>0 then
    for i=1,amnt do
      turnLeft()
    end  
  end
end
 
--debugp("Current Waypoint:"..getWaypoint().label)
 
function goToRelPos(pos,destructh,destructv)

  debugp("[RelPos] Going to relative position "..pos[1]..","..pos[2]..","..pos[3])
  
  destructh = destructh or false --defaults to false
  destructv = destructv or true --defaults to true
  
  x = pos[1]
  y = pos[2]
  z = pos[3]
  ux=0
  uz=0
  uy=0
   
  if x~=0 then ux = math.abs(x)/x end
  if y~=0 then uy = math.abs(y)/y end
  if z~=0 then uz = math.abs(z)/z end
 
 
  --y coord
  if uy~=0 then
    if uy>0 then --targ location is above us
      for i=1,math.abs(y) do
        if up()==false then
		  if destructv==true then
			mine(1)
			local c=0
			while up()==false do --keep mining until we go up correctly
			  mine(1)
			  c=c+1
			  if c>20 then debugp("[RelPos] Failed when going up!",true) return false end --if we try enough times then break
			end

		  else
		    debugp("[RelPos] [destructv=false] Failed when going up!",true)
			return false
		  end
		end	
      end
    elseif uy<0 then
      for i=1,math.abs(y) do
        if down()==false then
		  if destructv==true then
			mine(0)
			if down()~=true then debugp("[RelPos] Failed when going down!",true) return false end --if fail retunr fals
		  else 
		    debugp("[RelPos] [destructv=false] Failed when going down!",true)
		    return false
		  end
		end
      end
    end
  end
 
  --x coord
  if ux>0 then
    turnToDir(sides.posx)
  elseif ux<0 then
    turnToDir(sides.negx)
  end
  if ux~=0 then
  for i=1,math.abs(x) do
    if forward()==false then 
	  if destructh==true then
	    local c=0
	    while forward()==false do
		  mine()--keep swinging until we go forward
		  c=c+1
		  if c>20 then debugp("[RelPos] Failed when going forward in x direction!",true) return false end
		end
	  else
	    debugp("[RelPos] [destructh=false] Failed when going forward in x!",true)
		return false
	  end
	end
  end
  end
 
  --z coord
  if uz>0 then
    turnToDir(sides.posz)
  elseif uz<0 then
    turnToDir(sides.negz)
  end
  if uz~=0 then
  for i=1,math.abs(z) do
    if forward()==false then 
	  if destructh==true then
	    local c=0
	    while forward()==false do
		  r.swing()--keep swinging until we go forward
		  c=c+1
		  if c>20 then debugp("[RelPos] Failed when going forward in z direction!",true) return false end
		end
	  else
	    debugp("[RelPos] [destructh=false] Failed when going forward in z!",true)
		return false
	  end
	end
  end
  end
   
 return true
 
end
 
pos = {0,-3,0}
--goToRelPos(pos)


function meander() 
  debugp("[GoHome] [meander] Meandering..        " ,true)
  
  forwards=0
  while true do
	if forward()==false then turnRight()
	else 
  end
 
end 
 
function goHome()
  debugp("[GoHome] Going home")
  wp = getWaypoint()
  wp.position[2]=wp.position[2]-1
  if goToRelPos(wp.position)==false then 
	debugp("[GoHome] Failed to go home!",true) 
	
  
  end 
end
 
 
 
--=================
--high level mining   
--=================

--helper function, tells if a block is useful and should be got
function isHelpful(name,type)
  if name~=nil then
    if string.find(name,"ore")~=nil or string.find(name,"actual") then
      return true
    end
  end
  if type~=nil then
    if string.find(type,"ore")~=nil then
      return true
    end
  end
  return false
end
 
function getLocalSide(worldside)
  --up and down never need to be converted
  if worldside==0 or worldside==1 then
    return worldside
  end
  currentFacing=nav.getFacing()
  cF=dirmap[currentFacing]
  wS=dirmap[worldside]
  offset = cF%4
  localSide=wS-offset
--  print("Localside+1:"..localSide+1)
  return edirmap[localSide+5] --orig +1
end
 
 
--takes in worldSide
function tryToMine(side)
 
--  geolyzer uses the local side, this function takes worldside
--  print(getLocalSide(side))
  data = geo.analyze(getLocalSide(side))
  if isHelpful(data.name,data.type)==true then
    --mine it
--    print("Block on side"..side.." is useful!")
   
    turnToDir(side)
    mine(side)
 
    --go there
    if side==sides.up then 
	  local attempts=0
	  while up()==false do 
	    mine(1)
	    attempts=attempts+1
		if attempts>15 then do return end end
	  end
    elseif side==sides.down then down()
    else
	  local attempts=0
      while forward()==false do
	    mine()
		attempts=attempts+1
		if attempts>15 then do return end end
	  end
    end
 
    --see if more ore exist by checking sides
    for s=0,5 do
--      print("Trying to mine "..s)
      tryToMine(s)
    end        
 
    --turn back
    turnToDir(side)    
    --go back
    if side==sides.up then down()
    elseif side==sides.down then up()
    else
      back()
    end
     
  end  
end
 
--figure out next targets 
function loadNextTargets()
	getPositionData(status.spiraldata,
end 
 
 --side is either 0 or 1 for down or up
function checkForOres(side)
  for i=2,5 do
    tryToMine(i)
  end
  tryToMine(side)
end
 
function markShaftCompleted(side)
  if side==0 then status.targetLower=1
  elseif side==1 then status.targetUpper=1 end
end 
 
 --side is either 0 or 1 for down or up
function mineShaft(side)
  
  local attempts=0
  local distance=0
  while true do
	print("[mineShaft()] Attempt "..attempts.." to mine shaft")
	checkForOres(side) --look for something helpful
	local suc,rea=mine(side)
	if suc==false and rea=="block" then --we encountered bedrock
	  markShaftCompleted(side)
	  break -- stop mining shaft
	elseif suc==true and rea=="entity" then --we encountered an entity we can't go through
	  attempts=attempts+1
	  if attempts>10 then markShaftCompleted(side) break end --assume done
	else --we can continue going (mined block, or 
	  if side==0 then down() 
	  elseif side==1 then
        local upattempts=0	  
		while up()==false do
		  mine(1)
		  upattempts=upattempts+1
		  if upattempts>15 then break end 
		end
		if upattempts>15 then markShaftCompleted(side) break end
	  end	
	end

	
  end
end
 
--run next iteration of robot 
function step(initial)
  initial=initial or false
  if initial==true then loadStatus() getWaypoint() end 	
  if #status.spiraldata<1 then loadNextTargets() end	




end
 
 
 
--=================
-- testing section
--=================
step(true)
while true do
	step()
end


--goHome()
--tryToMine(sides.negz)
 
updateRecharge()
checkForOres()
 
 
--for i=0,5 do
--  turnToDir(i)
--end