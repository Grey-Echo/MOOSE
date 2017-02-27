--- Single-Player:**Yes** / Multi-Player:**Yes** / Core:**Yes** -- **Administer the scoring of player achievements, 
-- and create a CSV file logging the scoring events for use at team or squadron websites.**
-- 
-- ![Banner Image](..\Presentations\SCORING\Dia1.JPG)
--  
-- ===
-- 
-- # 1) @{Scoring#SCORING} class, extends @{Base#BASE}
-- 
-- The @{#SCORING} class administers the scoring of player achievements, 
-- and creates a CSV file logging the scoring events for use at team or squadron websites.
-- 
-- The scores are calculated by scoring the hits and destroys of objects that players make, 
-- which are @{Unit} and @{Static) objects within your mission.
-- 
-- Scores are calculated based on the threat level of the objects involved.
-- The threat level of a unit can be a value between 0 and 10.
-- A calculated score takes the threat level of the target divided by the threat level of the player unit.
-- This provides a value between 0.1 and 10. 
-- The stronger or the higher the threat of the player unit, the less score will be given in destroys.
-- That value can then be multiplied by a multiplier. A specific multiplier can be set for enemies and friendlies destroys.
-- 
-- If multiple players hit the same target, and finally the target gets destroyed, each player who contributed to the target
-- destruction, will receive a score. This is important for targets that require significant damage before it can be destroyed, like
-- ships or heavy planes.
-- 
-- **Additional scores** can be granted to **specific objects**, when the player(s) destroy these objects.
-- **Various @{Zone}s** can be defined for which scores are also granted when objects in that @{Zone} are destroyed.
-- This is **specifically useful** to designate **scenery targets on the map** that will generate points when destroyed.
-- 
-- With a small change in MissionScripting.lua, the scoring can also be logged in a CSV file.
-- That file can then be:
-- 
--   * Uploaded to a database or a BI tool to publish the scoring results to the player community.
--   * Uploaded in an (online) Excel like tool, using pivot tables and pivot charts to show mission results.
--   * Share amoung players after the mission to discuss mission results.
-- 
-- ## 1.1) Set the destroy score or penalty multiplier
-- 
-- Score multipliers can be set for scores granted when enemies or friendlies are destroyed.
-- Use the method @{#SCORING.SetMultiplierDestroyScore}() to set the multiplier of enemy destroys (positive destroys). 
-- Use the method @{#SCORING.SetMultiplierDestroyPenalty}() to set the multiplier of friendly destroys (negative destroys).
-- 
-- ## 1.2) Define special targets that will give extra scores.
-- 
-- Special targets can be set that will give extra scores to the players when these are destroyed.
-- Use the methods @{#SCORING.AddUnitScore}() and @{#SCORING.RemoveUnitScore}() to specify a special additional score for a specific @{Unit}s.
-- Use the methods @{#SCORING.AddStaticScore}() and @{#SCORING.RemoveStaticScore}() to specify a special additional score for a specific @{Static}s.
-- Use the method @{#SCORING.SetGroupGroup}() to specify a special additional score for a specific @{Group}s.
-- 
-- ## 1.3) Define destruction zones that will give extra scores.
-- 
-- Define zones of destruction. Any object destroyed within the zone of the given category will give extra points.
-- Use the method @{#SCORING.AddZoneScore} to add a @{Zone} for additional scoring.
-- Use the method @{#SCORING.RemoveZoneScore} to remove a @{Zone} for additional scoring.
-- There are interesting variations that can be achieved with this functionality. For example, if the @{Zone} is a @{Zone#ZONE_UNIT}, 
-- then the zone is a moving zone, and anything destroyed within that @{Zone} will generate points.
-- The other implementation could be to designate a scenery target (a building) in the mission editor surrounded by a @{Zone}, 
-- just large enough around that building.
-- 
-- ====
--
-- # **API CHANGE HISTORY**
--
-- The underlying change log documents the API changes. Please read this carefully. The following notation is used:
--
--   * **Added** parts are expressed in bold type face.
--   * _Removed_ parts are expressed in italic type face.
--
-- Hereby the change log:
--
-- 2017-02-26: Initial class and API.
--
-- ===
--
-- # **AUTHORS and CONTRIBUTIONS**
--
-- ### Contributions:
--
--   * **Wingthor**: Testing & Advice.
--   * **Dutch-Baron**: Testing & Advice.
--   * **[Whisper](http://forums.eagle.ru/member.php?u=3829): Testing.
--        
-- ### Authors:
--
--   * **FlightControl**: Concept, Design & Programming.
-- 
-- @module Scoring


--- The Scoring class
-- @type SCORING
-- @field Players A collection of the current players that have joined the game.
-- @extends Core.Base#BASE
SCORING = {
  ClassName = "SCORING",
  ClassID = 0,
  Players = {},
}

local _SCORINGCoalition =
  {
    [1] = "Red",
    [2] = "Blue",
  }

local _SCORINGCategory =
  {
    [Unit.Category.AIRPLANE] = "Plane",
    [Unit.Category.HELICOPTER] = "Helicopter",
    [Unit.Category.GROUND_UNIT] = "Vehicle",
    [Unit.Category.SHIP] = "Ship",
    [Unit.Category.STRUCTURE] = "Structure",
  }

--- Creates a new SCORING object to administer the scoring achieved by players.
-- @param #SCORING self
-- @param #string GameName The name of the game. This name is also logged in the CSV score file.
-- @return #SCORING self
-- @usage
-- -- Define a new scoring object for the mission Gori Valley.
-- ScoringObject = SCORING:New( "Gori Valley" )
function SCORING:New( GameName )

  -- Inherits from BASE
  local self = BASE:Inherit( self, BASE:New() )
  
  if GameName then 
    self.GameName = GameName
  else
    error( "A game name must be given to register the scoring results" )
  end
  
  -- Multipliers
  self.MultiplierDestroyScore = 10
  self.MultiplierDestroyPenalty = 20
  
  -- Additional Object scores
  self.ScoringObjects = {}
  
  -- Additional Zone scores.
  self.ScoringZones = {}
  
  self:HandleEvent( EVENTS.Dead, self._EventOnDeadOrCrash )
  self:HandleEvent( EVENTS.Crash, self._EventOnDeadOrCrash )
  self:HandleEvent( EVENTS.Hit, self._EventOnHit )

  --self.SchedulerId = routines.scheduleFunction( SCORING._FollowPlayersScheduled, { self }, 0, 5 )
  --self.SchedulerId = SCHEDULER:New( self, self._FollowPlayersScheduled, {}, 0, 5 )

  self:ScoreMenu()
  
  self:OpenCSV( GameName)

  return self
  
end

--- Set the multiplier for scoring valid destroys (enemy destroys).
-- A calculated score is a value between 0.1 and 10.
-- The multiplier magnifies the scores given to the players.
-- @param #SCORING self
-- @param #number Multiplier The multiplier of the score given.
function SCORING:SetMultiplierDestroyScore( Multiplier )

  self.MultiplierDestroyScore = Multiplier
  
  return self
end

--- Set the multiplier for scoring penalty destroys (friendly destroys).
-- A calculated score is a value between 0.1 and 10.
-- The multiplier magnifies the scores given to the players.
-- @param #SCORING self
-- @param #number Multiplier The multiplier of the score given.
-- @return #SCORING
function SCORING:SetMultiplierDestroyPenalty( Multiplier )

  self.MultiplierDestroyPenalty = Multiplier
  
  return self
end

--- Add a @{Unit} for additional scoring when the @{Unit} is destroyed.
-- Note that if there was already a @{Unit} declared within the scoring with the same name, 
-- then the old @{Unit}  will be replaced with the new @{Unit}.
-- @param #SCORING self
-- @param Wrapper.Unit#UNIT ScoreUnit The @{Unit} for which the Score needs to be given.
-- @param #number Score The Score value.
-- @return #SCORING
function SCORING:AddUnitScore( ScoreUnit, Score )

  local UnitName = ScoreUnit:GetName()

  self.ScoringObjects[UnitName] = Score
  
  return self
end

--- Removes a @{Unit} for additional scoring when the @{Unit} is destroyed.
-- @param #SCORING self
-- @param Wrapper.Unit#UNIT ScoreUnit The @{Unit} for which the Score needs to be given.
-- @return #SCORING
function SCORING:RemoveUnitScore( ScoreUnit )

  local UnitName = ScoreUnit:GetName()

  self.ScoringObjects[UnitName] = nil
  
  return self
end

--- Add a @{Static} for additional scoring when the @{Static} is destroyed.
-- Note that if there was already a @{Static} declared within the scoring with the same name, 
-- then the old @{Static}  will be replaced with the new @{Static}.
-- @param #SCORING self
-- @param Wrapper.Static#UNIT ScoreStatic The @{Static} for which the Score needs to be given.
-- @param #number Score The Score value.
-- @return #SCORING
function SCORING:AddStaticScore( ScoreStatic, Score )

  local StaticName = ScoreStatic:GetName()

  self.ScoringObjects[StaticName] = Score
  
  return self
end

--- Removes a @{Static} for additional scoring when the @{Static} is destroyed.
-- @param #SCORING self
-- @param Wrapper.Static#UNIT ScoreStatic The @{Static} for which the Score needs to be given.
-- @return #SCORING
function SCORING:RemoveStaticScore( ScoreStatic )

  local StaticName = ScoreStatic:GetName()

  self.ScoringObjects[StaticName] = nil
  
  return self
end


--- Specify a special additional score for a @{Group}.
-- @param #SCORING self
-- @param Wrapper.Group#GROUP ScoreGroup The @{Group} for which each @{Unit} a Score is given.
-- @param #number Score The Score value.
-- @return #SCORING
function SCORING:AddScoreGroup( ScoreGroup, Score )

  local ScoreUnits = ScoreGroup:GetUnits()

  for ScoreUnitID, ScoreUnit in pairs( ScoreUnits ) do
    local UnitName = ScoreUnit:GetName()
    self.ScoringObjects[UnitName] = Score
  end
  
  return self
end

--- Add a @{Zone} to define additional scoring when any object is destroyed in that zone.
-- Note that if a @{Zone} with the same name is already within the scoring added, the @{Zone} (type) and Score will be replaced!
-- This allows for a dynamic destruction zone evolution within your mission.
-- @param #SCORING self
-- @param Core.Zone#ZONE_BASE ScoreZone The @{Zone} which defines the destruction score perimeters. 
-- Note that a zone can be a polygon or a moving zone.
-- @param #number Score The Score value.
-- @return #SCORING
function SCORING:AddScoreZone( ScoreZone, Score )

  local ZoneName = ScoreZone:GetName()

  self.ScoringZones[ZoneName] = {}
  self.ScoringZones[ZoneName].ScoreZone = ScoreZone
  self.ScoringZones[ZoneName].Score = Score
  
  return self
end

--- Remove a @{Zone} for additional scoring.
-- The scoring will search if any @{Zone} is added with the given name, and will remove that zone from the scoring.
-- This allows for a dynamic destruction zone evolution within your mission.
-- @param #SCORING self
-- @param Core.Zone#ZONE_BASE ScoreZone The @{Zone} which defines the destruction score perimeters. 
-- Note that a zone can be a polygon or a moving zone.
-- @return #SCORING
function SCORING:RemoveScoreZone( ScoreZone )

  local ZoneName = ScoreZone:GetName()

  self.ScoringZones[ZoneName] = nil
  
  return self
end



--- Creates a score radio menu. Can be accessed using Radio -> F10.
-- @param #SCORING self
-- @return #SCORING self
function SCORING:ScoreMenu()
  self.Menu = MENU_MISSION:New( 'Scoring' )
  self.AllScoresMenu = MENU_MISSION_COMMAND:New( 'Score All Active Players', self.Menu, SCORING.ReportScoreAll, self )
  --- = COMMANDMENU:New('Your Current Score', ReportScore, SCORING.ReportScorePlayer, self )
  return self
end

--- Follows new players entering Clients within the DCSRTE.
-- TODO: Need to see if i can catch this also with an event. It will eliminate the schedule ...
function SCORING:_FollowPlayersScheduled()
  self:F3( "_FollowPlayersScheduled" )

  local ClientUnit = 0
  local CoalitionsData = { AlivePlayersRed = coalition.getPlayers(coalition.side.RED), AlivePlayersBlue = coalition.getPlayers(coalition.side.BLUE) }
  local unitId
  local unitData
  local AlivePlayerUnits = {}

  for CoalitionId, CoalitionData in pairs( CoalitionsData ) do
    self:T3( { "_FollowPlayersScheduled", CoalitionData } )
    for UnitId, UnitData in pairs( CoalitionData ) do
      self:_AddPlayerFromUnit( UnitData )
    end
  end
  
  return true
end




--- Add a new player entering a Unit.
-- @param #SCORING self
-- @param Wrapper.Unit#UNIT UnitData
function SCORING:_AddPlayerFromUnit( UnitData )
  self:F( UnitData )

  if UnitData:IsAlive() then
    local UnitName = UnitData:GetName()
    local PlayerName = UnitData:GetPlayerName()
    local UnitDesc = UnitData:GetDesc()
    local UnitCategory = UnitDesc.category
    local UnitCoalition = UnitData:GetCoalition()
    local UnitTypeName = UnitData:GetTypeName()

    self:T( { PlayerName, UnitName, UnitCategory, UnitCoalition, UnitTypeName } )

    if self.Players[PlayerName] == nil then -- I believe this is the place where a Player gets a life in a mission when he enters a unit ...
      self.Players[PlayerName] = {}
      self.Players[PlayerName].Hit = {}
      self.Players[PlayerName].Destroy = {}
      self.Players[PlayerName].Mission = {}

      -- for CategoryID, CategoryName in pairs( SCORINGCategory ) do
      -- self.Players[PlayerName].Hit[CategoryID] = {}
      -- self.Players[PlayerName].Destroy[CategoryID] = {}
      -- end
      self.Players[PlayerName].HitPlayers = {}
      self.Players[PlayerName].Score = 0
      self.Players[PlayerName].Penalty = 0
      self.Players[PlayerName].PenaltyCoalition = 0
      self.Players[PlayerName].PenaltyWarning = 0
    end

    if not self.Players[PlayerName].UnitCoalition then
      self.Players[PlayerName].UnitCoalition = UnitCoalition
    else
      if self.Players[PlayerName].UnitCoalition ~= UnitCoalition then
        self.Players[PlayerName].Penalty = self.Players[PlayerName].Penalty + 50
        self.Players[PlayerName].PenaltyCoalition = self.Players[PlayerName].PenaltyCoalition + 1
        MESSAGE:New( "Player '" .. PlayerName .. "' changed coalition from " .. _SCORINGCoalition[self.Players[PlayerName].UnitCoalition] .. " to " .. _SCORINGCoalition[UnitCoalition] ..
          "(changed " .. self.Players[PlayerName].PenaltyCoalition .. " times the coalition). 50 Penalty points added.",
          2
        ):ToAll()
        self:ScoreCSV( PlayerName, "COALITION_PENALTY",  1, -50, self.Players[PlayerName].UnitName, _SCORINGCoalition[self.Players[PlayerName].UnitCoalition], _SCORINGCategory[self.Players[PlayerName].UnitCategory], self.Players[PlayerName].UnitType,
          UnitName, _SCORINGCoalition[UnitCoalition], _SCORINGCategory[UnitCategory], UnitData:getTypeName() )
      end
    end
    self.Players[PlayerName].UnitName = UnitName
    self.Players[PlayerName].UnitCoalition = UnitCoalition
    self.Players[PlayerName].UnitCategory = UnitCategory
    self.Players[PlayerName].UnitType = UnitTypeName
    self.Players[PlayerName].UNIT = UnitData 

    if self.Players[PlayerName].Penalty > 100 then
      if self.Players[PlayerName].PenaltyWarning < 1 then
        MESSAGE:New( "Player '" .. PlayerName .. "': WARNING! If you continue to commit FRATRICIDE and have a PENALTY score higher than 150, you will be COURT MARTIALED and DISMISSED from this mission! \nYour total penalty is: " .. self.Players[PlayerName].Penalty,
          30
        ):ToAll()
        self.Players[PlayerName].PenaltyWarning = self.Players[PlayerName].PenaltyWarning + 1
      end
    end

    if self.Players[PlayerName].Penalty > 150 then
      local ClientGroup = GROUP:NewFromDCSUnit( UnitData )
      ClientGroup:Destroy()
      MESSAGE:New( "Player '" .. PlayerName .. "' committed FRATRICIDE, he will be COURT MARTIALED and is DISMISSED from this mission!",
        10
      ):ToAll()
    end

  end
end


--- Registers Scores the players completing a Mission Task.
-- @param #SCORING self
-- @param Tasking.Mission#MISSION Mission
-- @param Wrapper.Unit#UNIT PlayerUnit
-- @param #string Text
-- @param #number Score
function SCORING:_AddMissionTaskScore( Mission, PlayerUnit, Text, Score )

  local PlayerName = PlayerUnit:GetPlayerName()
  local MissionName = Mission:GetName()

  self:E( { Mission:GetName(), PlayerUnit.UnitName, PlayerName, Text, Score } )

  -- PlayerName can be nil, if the Unit with the player crashed or due to another reason.
  if PlayerName then 
    local PlayerData = self.Players[PlayerName]
  
    if not PlayerData.Mission[MissionName] then
      PlayerData.Mission[MissionName] = {}
      PlayerData.Mission[MissionName].ScoreTask = 0
      PlayerData.Mission[MissionName].ScoreMission = 0
    end
  
    self:T( PlayerName )
    self:T( PlayerData.Mission[MissionName] )
  
    PlayerData.Score = self.Players[PlayerName].Score + Score
    PlayerData.Mission[MissionName].ScoreTask = self.Players[PlayerName].Mission[MissionName].ScoreTask + Score
  
    MESSAGE:New( "Player '" .. PlayerName .. "' has " .. Text .. " in Mission '" .. MissionName .. "'. " ..
      Score .. " task score!",
      30 ):ToAll()
  
    self:ScoreCSV( PlayerName, "TASK_" .. MissionName:gsub( ' ', '_' ), 1, Score, PlayerUnit:GetName() )
  end
end


--- Registers Mission Scores for possible multiple players that contributed in the Mission.
-- @param #SCORING self
-- @param Tasking.Mission#MISSION Mission
-- @param Wrapper.Unit#UNIT PlayerUnit
-- @param #string Text
-- @param #number Score
function SCORING:_AddMissionScore( Mission, Text, Score )
  
  local MissionName = Mission:GetName()

  self:E( { Mission, Text, Score } )
  self:E( self.Players )

  for PlayerName, PlayerData in pairs( self.Players ) do

    self:E( PlayerData )
    if PlayerData.Mission[MissionName] then

      PlayerData.Score = PlayerData.Score + Score
      PlayerData.Mission[MissionName].ScoreMission = PlayerData.Mission[MissionName].ScoreMission + Score

      MESSAGE:New( "Player '" .. PlayerName .. "' has " .. Text .. " in Mission '" .. MissionName .. "'. " ..
        Score .. " mission score!",
        60 ):ToAll()

      self:ScoreCSV( PlayerName, "MISSION_" .. MissionName:gsub( ' ', '_' ), 1, Score )
    end
  end
end

--- Handles the OnHit event for the scoring.
-- @param #SCORING self
-- @param Core.Event#EVENTDATA Event
function SCORING:_EventOnHit( Event )
  self:F( { Event } )

  local InitUnit = nil
  local InitUNIT = nil
  local InitUnitName = ""
  local InitGroup = nil
  local InitGroupName = ""
  local InitPlayerName = nil

  local InitCoalition = nil
  local InitCategory = nil
  local InitType = nil
  local InitUnitCoalition = nil
  local InitUnitCategory = nil
  local InitUnitType = nil

  local TargetUnit = nil
  local TargetUNIT = nil
  local TargetUnitName = ""
  local TargetGroup = nil
  local TargetGroupName = ""
  local TargetPlayerName = nil

  local TargetCoalition = nil
  local TargetCategory = nil
  local TargetType = nil
  local TargetUnitCoalition = nil
  local TargetUnitCategory = nil
  local TargetUnitType = nil

  if Event.IniDCSUnit then

    InitUnit = Event.IniDCSUnit
    InitUNIT = Event.IniUnit
    InitUnitName = Event.IniDCSUnitName
    InitGroup = Event.IniDCSGroup
    InitGroupName = Event.IniDCSGroupName
    InitPlayerName = Event.IniPlayerName

    InitCoalition = InitUnit:getCoalition()
    --TODO: Workaround Client DCS Bug
    --InitCategory = InitUnit:getCategory()
    InitCategory = InitUnit:getDesc().category
    InitType = InitUnit:getTypeName()

    InitUnitCoalition = _SCORINGCoalition[InitCoalition]
    InitUnitCategory = _SCORINGCategory[InitCategory]
    InitUnitType = InitType

    self:T( { InitUnitName, InitGroupName, InitPlayerName, InitCoalition, InitCategory, InitType , InitUnitCoalition, InitUnitCategory, InitUnitType } )
  end


  if Event.TgtDCSUnit then

    TargetUnit = Event.TgtDCSUnit
    TargetUNIT = Event.TgtUnit
    TargetUnitName = Event.TgtDCSUnitName
    TargetGroup = Event.TgtDCSGroup
    TargetGroupName = Event.TgtDCSGroupName
    TargetPlayerName = Event.TgtPlayerName

    TargetCoalition = TargetUnit:getCoalition()
    --TODO: Workaround Client DCS Bug
    --TargetCategory = TargetUnit:getCategory()
    TargetCategory = TargetUnit:getDesc().category
    TargetType = TargetUnit:getTypeName()

    TargetUnitCoalition = _SCORINGCoalition[TargetCoalition]
    TargetUnitCategory = _SCORINGCategory[TargetCategory]
    TargetUnitType = TargetType

    self:T( { TargetUnitName, TargetGroupName, TargetPlayerName, TargetCoalition, TargetCategory, TargetType, TargetUnitCoalition, TargetUnitCategory, TargetUnitType } )
  end

  if InitPlayerName ~= nil then -- It is a player that is hitting something
    self:_AddPlayerFromUnit( InitUNIT )
    if self.Players[InitPlayerName] then -- This should normally not happen, but i'll test it anyway.
      if TargetPlayerName ~= nil then -- It is a player hitting another player ...
        self:_AddPlayerFromUnit( TargetUNIT )
      end

      self:T( "Hitting Something" )
      
      -- What is he hitting?
      if TargetCategory then
  
        -- A target got hit, score it.
        -- Player contains the score data from self.Players[InitPlayerName]
        local Player = self.Players[InitPlayerName]
        
        -- Ensure there is a hit table per TargetCategory and TargetUnitName.
        Player.Hit[TargetCategory] = Player.Hit[TargetCategory] or {}
        Player.Hit[TargetCategory][TargetUnitName] = Player.Hit[TargetCategory][TargetUnitName] or {}
        
        -- PlayerHit contains the score counters and data per unit that was hit.
        local PlayerHit = Player.Hit[TargetCategory][TargetUnitName]
         
        PlayerHit.Score = PlayerHit.Score or 0
        PlayerHit.Penalty = PlayerHit.Penalty or 0
        PlayerHit.ScoreHit = PlayerHit.ScoreHit or 0
        PlayerHit.PenaltyHit = PlayerHit.PenaltyHit or 0
        PlayerHit.TimeStamp = PlayerHit.TimeStamp or 0
        PlayerHit.UNIT = PlayerHit.UNIT or TargetUNIT

        -- Only grant hit scores if there was more than one second between the last hit.        
        if timer.getTime() - PlayerHit.TimeStamp > 1 then
          PlayerHit.TimeStamp = timer.getTime()
        
          if TargetPlayerName ~= nil then -- It is a player hitting another player ...
    
            -- Ensure there is a Player to Player hit reference table.
            Player.HitPlayers[TargetPlayerName] = true
          end
          
          local Score = 0
          if InitCoalition == TargetCoalition then
            Player.Penalty = Player.Penalty + 10
            PlayerHit.Penalty = PlayerHit.Penalty + 10
            PlayerHit.PenaltyHit = PlayerHit.PenaltyHit + 1
    
            if TargetPlayerName ~= nil then -- It is a player hitting another player ...
              MESSAGE:New( "Player '" .. InitPlayerName .. "' hit friendly player '" .. TargetPlayerName .. "' " .. TargetUnitCategory .. " ( " .. TargetType .. " ) " ..
                PlayerHit.PenaltyHit .. " times. Penalty: -" .. PlayerHit.Penalty ..
                ".  Score Total:" .. Player.Score - Player.Penalty,
                2
              ):ToAll()
            else
              MESSAGE:New( "Player '" .. InitPlayerName .. "' hit a friendly " .. TargetUnitCategory .. " ( " .. TargetType .. " ) " ..
                PlayerHit.PenaltyHit .. " times. Penalty: -" .. PlayerHit.Penalty ..
                ".  Score Total:" .. Player.Score - Player.Penalty,
                2
              ):ToAll()
            end
            self:ScoreCSV( InitPlayerName, "HIT_PENALTY", 1, -25, InitUnitName, InitUnitCoalition, InitUnitCategory, InitUnitType, TargetUnitName, TargetUnitCoalition, TargetUnitCategory, TargetUnitType )
          else
            Player.Score = Player.Score + 1
            PlayerHit.Score = PlayerHit.Score + 1
            PlayerHit.ScoreHit = PlayerHit.ScoreHit + 1
            if TargetPlayerName ~= nil then -- It is a player hitting another player ...
              MESSAGE:New( "Player '" .. InitPlayerName .. "' hit enemy player '" .. TargetPlayerName .. "' "  .. TargetUnitCategory .. " ( " .. TargetType .. " ) " ..
                PlayerHit.ScoreHit .. " times. Score: " .. PlayerHit.Score ..
                ".  Score Total:" .. Player.Score - Player.Penalty,
                2
              ):ToAll()
            else
              MESSAGE:New( "Player '" .. InitPlayerName .. "' hit an enemy " .. TargetUnitCategory .. " ( " .. TargetType .. " ) " ..
                PlayerHit.ScoreHit .. " times. Score: " .. PlayerHit.Score ..
                ".  Score Total:" .. Player.Score - Player.Penalty,
                2
              ):ToAll()
            end
            self:ScoreCSV( InitPlayerName, "HIT_SCORE", 1, 1, InitUnitName, InitUnitCoalition, InitUnitCategory, InitUnitType, TargetUnitName, TargetUnitCoalition, TargetUnitCategory, TargetUnitType )
          end
        end
      end
    end
  elseif InitPlayerName == nil then -- It is an AI hitting a player???

  end
end

--- Track  DEAD or CRASH events for the scoring.
-- @param #SCORING self
-- @param Core.Event#EVENTDATA Event
function SCORING:_EventOnDeadOrCrash( Event )
  self:F( { Event } )

  local TargetUnit = nil
  local TargetGroup = nil
  local TargetUnitName = ""
  local TargetGroupName = ""
  local TargetPlayerName = ""
  local TargetCoalition = nil
  local TargetCategory = nil
  local TargetType = nil
  local TargetUnitCoalition = nil
  local TargetUnitCategory = nil
  local TargetUnitType = nil

  if Event.IniDCSUnit then

    TargetUnit = Event.IniDCSUnit
    TargetUnitName = Event.IniDCSUnitName
    TargetGroup = Event.IniDCSGroup
    TargetGroupName = Event.IniDCSGroupName
    TargetPlayerName = Event.IniPlayerName

    TargetCoalition = TargetUnit:getCoalition()
    --TargetCategory = TargetUnit:getCategory()
    TargetCategory = TargetUnit:getDesc().category  -- Workaround
    TargetType = TargetUnit:getTypeName()

    TargetUnitCoalition = _SCORINGCoalition[TargetCoalition]
    TargetUnitCategory = _SCORINGCategory[TargetCategory]
    TargetUnitType = TargetType

    self:T( { TargetUnitName, TargetGroupName, TargetPlayerName, TargetCoalition, TargetCategory, TargetType } )
  end

  -- Player contains the score and reference data for the player.
  for PlayerName, Player in pairs( self.Players ) do
    if Player then -- This should normally not happen, but i'll test it anyway.
      self:T( "Something got destroyed" )

      -- Some variables
      local InitUnitName = Player.UnitName
      local InitUnitType = Player.UnitType
      local InitCoalition = Player.UnitCoalition
      local InitCategory = Player.UnitCategory
      local InitUnitCoalition = _SCORINGCoalition[InitCoalition]
      local InitUnitCategory = _SCORINGCategory[InitCategory]

      self:T( { InitUnitName, InitUnitType, InitUnitCoalition, InitCoalition, InitUnitCategory, InitCategory } )

      -- What is he hitting?
      if TargetCategory then
        if Player and Player.Hit and Player.Hit[TargetCategory] and Player.Hit[TargetCategory][TargetUnitName] then -- Was there a hit for this unit for this player before registered???
        
          
          Player.Destroy[TargetCategory] = Player.Destroy[TargetCategory] or {}
          Player.Destroy[TargetCategory][TargetType] = Player.Destroy[TargetCategory][TargetType] or {}

          -- PlayerDestroy contains the destroy score data per category and target type of the player.
          local TargetDestroy = Player.Destroy[TargetCategory][TargetType]
          Player.Destroy[TargetCategory][TargetType] = {}
          TargetDestroy.Score = TargetDestroy.Score or 0
          TargetDestroy.ScoreDestroy = TargetDestroy.ScoreDestroy or 0
          TargetDestroy.Penalty =  TargetDestroy.Penalty or 0
          TargetDestroy.PenaltyDestroy = TargetDestroy.PenaltyDestroy or 0
          TargetDestroy.UNIT = TargetDestroy.UNIT or Player.Hit[TargetCategory][TargetUnitName].UNIT
  
          if InitCoalition == TargetCoalition then
            local ThreatLevelTarget, ThreatTypeTarget = TargetDestroy.UNIT:GetThreatLevel()
            local ThreatLevelPlayer = Player.UNIT:GetThreatLevel()
            local ThreatLevel = math.ceil( ( ThreatLevelTarget / ThreatLevelPlayer ) * self.MultiplierDestroyPenalty )
            self:E( { ThreatLevel = ThreatLevel, ThreatLevelTarget = ThreatLevelTarget, ThreatTypeTarget = ThreatTypeTarget, ThreatLevelPlayer = ThreatLevelPlayer  } )
            
            Player.Penalty = Player.Penalty + ThreatLevel
            TargetDestroy.Penalty = TargetDestroy.Penalty + ThreatLevel
            TargetDestroy.PenaltyDestroy = TargetDestroy.PenaltyDestroy + 1
            
            if Player.HitPlayers[TargetPlayerName] then -- A player destroyed another player
              MESSAGE:New( "Player '" .. PlayerName .. "' destroyed friendly player '" .. TargetPlayerName .. "' " .. TargetUnitCategory .. " ( " .. ThreatTypeTarget .. " ) " ..
                TargetDestroy.PenaltyDestroy .. " times. Penalty: -" .. TargetDestroy.Penalty ..
                ".  Score Total:" .. Player.Score - Player.Penalty,
                15 ):ToAll()
            else
              MESSAGE:New( "Player '" .. PlayerName .. "' destroyed a friendly " .. TargetUnitCategory .. " ( " .. ThreatTypeTarget .. " ) " ..
                TargetDestroy.PenaltyDestroy .. " times. Penalty: -" .. TargetDestroy.Penalty ..
                ".  Score Total:" .. Player.Score - Player.Penalty,
                15 ):ToAll()
            end
            self:ScoreCSV( PlayerName, "DESTROY_PENALTY", 1, -125, InitUnitName, InitUnitCoalition, InitUnitCategory, InitUnitType, TargetUnitName, TargetUnitCoalition, TargetUnitCategory, TargetUnitType )
          else

            local ThreatLevelTarget, ThreatTypeTarget = TargetDestroy.UNIT:GetThreatLevel()
            local ThreatLevelPlayer = Player.UNIT:GetThreatLevel()
            local ThreatLevel = math.ceil( ( ThreatLevelTarget / ThreatLevelPlayer ) * self.MultiplierDestroyScore )
            self:E( { ThreatLevel = ThreatLevel, ThreatLevelTarget = ThreatLevelTarget, ThreatTypeTarget = ThreatTypeTarget, ThreatLevelPlayer = ThreatLevelPlayer  } )

            Player.Score = Player.Score + ThreatLevel
            TargetDestroy.Score = TargetDestroy.Score + ThreatLevel
            TargetDestroy.ScoreDestroy = TargetDestroy.ScoreDestroy + 1
            if Player.HitPlayers[TargetPlayerName] then -- A player destroyed another player
              MESSAGE:New( "Player '" .. PlayerName .. "' destroyed enemy player '" .. TargetPlayerName .. "' " .. TargetUnitCategory .. " ( " .. ThreatTypeTarget .. " ) " ..
                TargetDestroy.ScoreDestroy .. " times. Score: " .. TargetDestroy.Score ..
                ".  Score Total:" .. Player.Score - Player.Penalty,
                15 ):ToAll()
            else
              MESSAGE:New( "Player '" .. PlayerName .. "' destroyed an enemy " .. TargetUnitCategory .. " ( " .. ThreatTypeTarget .. " ) " ..
                TargetDestroy.ScoreDestroy .. " times. Score: " .. TargetDestroy.Score ..
                ".  Total:" .. Player.Score - Player.Penalty,
                15 ):ToAll()
            end
            
            local UnitName = TargetDestroy.UNIT:GetName()
            local Score = self.ScoringObjects[UnitName]
            if Score then
              Player.Score = Player.Score + Score
              TargetDestroy.Score = TargetDestroy.Score + Score
              MESSAGE:New( "Special target '" .. TargetUnitCategory .. " ( " .. ThreatTypeTarget .. " ) " .. " destroyed! " .. 
                "Player '" .. PlayerName .. "' receives an extra " .. Score .. " points! Total: " .. Player.Score - Player.Penalty,
                15 ):ToAll()
            end
            
            -- Check if there are Zones where the destruction happened.
            for ZoneName, ScoreZoneData in pairs( self.ScoreZones ) do
              local ScoreZone = ScoreZoneData.ScoreZone -- Core.Zone#ZONE_BASE
              local Score = ScoreZoneData.Score
              if ScoreZone:IsPointVec2InZone( TargetDestroy.UNIT:GetPointVec2() ) then
                Player.Score = Player.Score + Score
                TargetDestroy.Score = TargetDestroy.Score + Score
                MESSAGE:New( "Target hit in zone '" .. ScoreZone:GetName() .. "'." .. 
                  "Player '" .. PlayerName .. "' receives an extra " .. Score .. " points! Total: " .. Player.Score - Player.Penalty,
                  15 ):ToAll()
              end
            end
                          
            self:ScoreCSV( PlayerName, "DESTROY_SCORE", 1, 10, InitUnitName, InitUnitCoalition, InitUnitCategory, InitUnitType, TargetUnitName, TargetUnitCoalition, TargetUnitCategory, TargetUnitType )
          end
        end
      end
    end
  end
end


function SCORING:ReportScoreAll()

  env.info( "Hello World " )

  local ScoreMessage = ""
  local PlayerMessage = ""

  self:T( "Score Report" )

  for PlayerName, PlayerData in pairs( self.Players ) do
    if PlayerData then -- This should normally not happen, but i'll test it anyway.
      self:T( "Score Player: " .. PlayerName )

      -- Some variables
      local InitUnitCoalition = _SCORINGCoalition[PlayerData.UnitCoalition]
      local InitUnitCategory = _SCORINGCategory[PlayerData.UnitCategory]
      local InitUnitType = PlayerData.UnitType
      local InitUnitName = PlayerData.UnitName

      local PlayerScore = 0
      local PlayerPenalty = 0

      ScoreMessage = ":\n"

      local ScoreMessageHits = ""

      for CategoryID, CategoryName in pairs( _SCORINGCategory ) do
        self:T( CategoryName )
        if PlayerData.Hit[CategoryID] then
          local Score = 0
          local ScoreHit = 0
          local Penalty = 0
          local PenaltyHit = 0
          self:T( "Hit scores exist for player " .. PlayerName )
          for UnitName, UnitData in pairs( PlayerData.Hit[CategoryID] ) do
            Score = Score + UnitData.Score
            ScoreHit = ScoreHit + UnitData.ScoreHit
            Penalty = Penalty + UnitData.Penalty
            PenaltyHit = UnitData.PenaltyHit
          end
          local ScoreMessageHit = string.format( "%s:%d  ", CategoryName, Score - Penalty )
          self:T( ScoreMessageHit )
          ScoreMessageHits = ScoreMessageHits .. ScoreMessageHit
          PlayerScore = PlayerScore + Score
          PlayerPenalty = PlayerPenalty + Penalty
        else
        --ScoreMessageHits = ScoreMessageHits .. string.format( "%s:%d  ", string.format(CategoryName, 1, 1), 0 )
        end
      end
      if ScoreMessageHits ~= "" then
        ScoreMessage = ScoreMessage .. "  Hits: " .. ScoreMessageHits .. "\n"
      end

      local ScoreMessageDestroys = ""
      for CategoryID, CategoryName in pairs( _SCORINGCategory ) do
        self:T( "Destroy scores exist for player " .. PlayerName )
        if PlayerData.Destroy[CategoryID] then
          local Score = 0
          local ScoreDestroy = 0
          local Penalty = 0
          local PenaltyDestroy = 0

          for UnitName, UnitData in pairs( PlayerData.Destroy[CategoryID] ) do
            Score = Score + UnitData.Score
            ScoreDestroy = ScoreDestroy + UnitData.ScoreDestroy
            Penalty = Penalty + UnitData.Penalty
            PenaltyDestroy = PenaltyDestroy + UnitData.PenaltyDestroy
          end

          local ScoreMessageDestroy = string.format( "  %s:%d  ", CategoryName, Score - Penalty )
          self:T( ScoreMessageDestroy )
          ScoreMessageDestroys = ScoreMessageDestroys .. ScoreMessageDestroy

          PlayerScore = PlayerScore + Score
          PlayerPenalty = PlayerPenalty + Penalty
        else
        --ScoreMessageDestroys = ScoreMessageDestroys .. string.format( "%s:%d  ", string.format(CategoryName, 1, 1), 0 )
        end
      end
      if ScoreMessageDestroys ~= "" then
        ScoreMessage = ScoreMessage .. "  Destroys: " .. ScoreMessageDestroys .. "\n"
      end

      local ScoreMessageCoalitionChangePenalties = ""
      if PlayerData.PenaltyCoalition ~= 0 then
        ScoreMessageCoalitionChangePenalties = ScoreMessageCoalitionChangePenalties .. string.format( " -%d (%d changed)", PlayerData.Penalty, PlayerData.PenaltyCoalition )
        PlayerPenalty = PlayerPenalty + PlayerData.Penalty
      end
      if ScoreMessageCoalitionChangePenalties ~= "" then
        ScoreMessage = ScoreMessage .. "  Coalition Penalties: " .. ScoreMessageCoalitionChangePenalties .. "\n"
      end

      local ScoreMessageMission = ""
      local ScoreMission = 0
      local ScoreTask = 0
      for MissionName, MissionData in pairs( PlayerData.Mission ) do
        ScoreMission = ScoreMission + MissionData.ScoreMission
        ScoreTask = ScoreTask + MissionData.ScoreTask
        ScoreMessageMission = ScoreMessageMission .. "'" .. MissionName .. "'; "
      end
      PlayerScore = PlayerScore + ScoreMission + ScoreTask

      if ScoreMessageMission ~= "" then
        ScoreMessage = ScoreMessage .. "  Tasks: " .. ScoreTask .. " Mission: " .. ScoreMission .. " ( " .. ScoreMessageMission .. ")\n"
      end

      PlayerMessage = PlayerMessage .. string.format( "Player '%s' Score:%d (%d Score -%d Penalties)%s", PlayerName, PlayerScore - PlayerPenalty, PlayerScore, PlayerPenalty, ScoreMessage )
    end
  end
  MESSAGE:New( PlayerMessage, 30, "Player Scores" ):ToAll()
end


function SCORING:ReportScorePlayer()

  env.info( "Hello World " )

  local ScoreMessage = ""
  local PlayerMessage = ""

  self:T( "Score Report" )

  for PlayerName, PlayerData in pairs( self.Players ) do
    if PlayerData then -- This should normally not happen, but i'll test it anyway.
      self:T( "Score Player: " .. PlayerName )

      -- Some variables
      local InitUnitCoalition = _SCORINGCoalition[PlayerData.UnitCoalition]
      local InitUnitCategory = _SCORINGCategory[PlayerData.UnitCategory]
      local InitUnitType = PlayerData.UnitType
      local InitUnitName = PlayerData.UnitName

      local PlayerScore = 0
      local PlayerPenalty = 0

      ScoreMessage = ""

      local ScoreMessageHits = ""

      for CategoryID, CategoryName in pairs( _SCORINGCategory ) do
        self:T( CategoryName )
        if PlayerData.Hit[CategoryID] then
          local Score = 0
          local ScoreHit = 0
          local Penalty = 0
          local PenaltyHit = 0
          self:T( "Hit scores exist for player " .. PlayerName )
          for UnitName, UnitData in pairs( PlayerData.Hit[CategoryID] ) do
            Score = Score + UnitData.Score
            ScoreHit = ScoreHit + UnitData.ScoreHit
            Penalty = Penalty + UnitData.Penalty
            PenaltyHit = UnitData.PenaltyHit
          end
          local ScoreMessageHit = string.format( "\n    %s = %d score(%d;-%d) hits(#%d;#-%d)", CategoryName, Score - Penalty, Score, Penalty, ScoreHit,  PenaltyHit )
          self:T( ScoreMessageHit )
          ScoreMessageHits = ScoreMessageHits .. ScoreMessageHit
          PlayerScore = PlayerScore + Score
          PlayerPenalty = PlayerPenalty + Penalty
        else
        --ScoreMessageHits = ScoreMessageHits .. string.format( "%s:%d  ", string.format(CategoryName, 1, 1), 0 )
        end
      end
      if ScoreMessageHits ~= "" then
        ScoreMessage = ScoreMessage .. "\n  Hits: " .. ScoreMessageHits .. " "
      end

      local ScoreMessageDestroys = ""
      for CategoryID, CategoryName in pairs( _SCORINGCategory ) do
        self:T( "Destroy scores exist for player " .. PlayerName )
        if PlayerData.Destroy[CategoryID] then
          local Score = 0
          local ScoreDestroy = 0
          local Penalty = 0
          local PenaltyDestroy = 0

          for UnitName, UnitData in pairs( PlayerData.Destroy[CategoryID] ) do
            Score = Score + UnitData.Score
            ScoreDestroy = ScoreDestroy + UnitData.ScoreDestroy
            Penalty = Penalty + UnitData.Penalty
            PenaltyDestroy = PenaltyDestroy + UnitData.PenaltyDestroy
          end

          local ScoreMessageDestroy = string.format( "\n    %s = %d score(%d;-%d) hits(#%d;#-%d)", CategoryName, Score - Penalty, Score, Penalty, ScoreDestroy, PenaltyDestroy )
          self:T( ScoreMessageDestroy )
          ScoreMessageDestroys = ScoreMessageDestroys .. ScoreMessageDestroy

          PlayerScore = PlayerScore + Score
          PlayerPenalty = PlayerPenalty + Penalty
        else
        --ScoreMessageDestroys = ScoreMessageDestroys .. string.format( "%s:%d  ", string.format(CategoryName, 1, 1), 0 )
        end
      end
      if ScoreMessageDestroys ~= "" then
        ScoreMessage = ScoreMessage .. "\n  Destroys: " .. ScoreMessageDestroys .. " "
      end

      local ScoreMessageCoalitionChangePenalties = ""
      if PlayerData.PenaltyCoalition ~= 0 then
        ScoreMessageCoalitionChangePenalties = ScoreMessageCoalitionChangePenalties .. string.format( " -%d (%d changed)", PlayerData.Penalty, PlayerData.PenaltyCoalition )
        PlayerPenalty = PlayerPenalty + PlayerData.Penalty
      end
      if ScoreMessageCoalitionChangePenalties ~= "" then
        ScoreMessage = ScoreMessage .. "\n  Coalition: " .. ScoreMessageCoalitionChangePenalties .. " "
      end

      local ScoreMessageMission = ""
      local ScoreMission = 0
      local ScoreTask = 0
      for MissionName, MissionData in pairs( PlayerData.Mission ) do
        ScoreMission = ScoreMission + MissionData.ScoreMission
        ScoreTask = ScoreTask + MissionData.ScoreTask
        ScoreMessageMission = ScoreMessageMission .. "'" .. MissionName .. "'; "
      end
      PlayerScore = PlayerScore + ScoreMission + ScoreTask

      if ScoreMessageMission ~= "" then
        ScoreMessage = ScoreMessage .. "\n  Tasks: " .. ScoreTask .. " Mission: " .. ScoreMission .. " ( " .. ScoreMessageMission .. ") "
      end

      PlayerMessage = PlayerMessage .. string.format( "Player '%s' Score = %d ( %d Score, -%d Penalties ):%s", PlayerName, PlayerScore - PlayerPenalty, PlayerScore, PlayerPenalty, ScoreMessage )
    end
  end
  MESSAGE:New( PlayerMessage, 30, "Player Scores" ):ToAll()

end


function SCORING:SecondsToClock(sSeconds)
  local nSeconds = sSeconds
  if nSeconds == 0 then
    --return nil;
    return "00:00:00";
  else
    nHours = string.format("%02.f", math.floor(nSeconds/3600));
    nMins = string.format("%02.f", math.floor(nSeconds/60 - (nHours*60)));
    nSecs = string.format("%02.f", math.floor(nSeconds - nHours*3600 - nMins *60));
    return nHours..":"..nMins..":"..nSecs
  end
end

--- Opens a score CSV file to log the scores.
-- @param #SCORING self
-- @param #string ScoringCSV
-- @return #SCORING self
-- @usage
-- -- Open a new CSV file to log the scores of the game Gori Valley. Let the name of the CSV file begin with "Player Scores".
-- ScoringObject = SCORING:New( "Gori Valley" )
-- ScoringObject:OpenCSV( "Player Scores" )
function SCORING:OpenCSV( ScoringCSV )
  self:F( ScoringCSV )
  
  if lfs and io and os then
    if ScoringCSV then
      self.ScoringCSV = ScoringCSV
      local fdir = lfs.writedir() .. [[Logs\]] .. self.ScoringCSV .. " " .. os.date( "%Y-%m-%d %H-%M-%S" ) .. ".csv"

      self.CSVFile, self.err = io.open( fdir, "w+" )
      if not self.CSVFile then
        error( "Error: Cannot open CSV file in " .. lfs.writedir() )
      end

      self.CSVFile:write( '"GameName","RunTime","Time","PlayerName","ScoreType","PlayerUnitCoaltion","PlayerUnitCategory","PlayerUnitType","PlayerUnitName","TargetUnitCoalition","TargetUnitCategory","TargetUnitType","TargetUnitName","Times","Score"\n' )
  
      self.RunTime = os.date("%y-%m-%d_%H-%M-%S")
    else
      error( "A string containing the CSV file name must be given." )
    end
  else
    self:E( "The MissionScripting.lua file has not been changed to allow lfs, io and os modules to be used..." )
  end
  return self
end


--- Registers a score for a player.
-- @param #SCORING self
-- @param #string PlayerName The name of the player.
-- @param #string ScoreType The type of the score.
-- @param #string ScoreTimes The amount of scores achieved.
-- @param #string ScoreAmount The score given.
-- @param #string PlayerUnitName The unit name of the player.
-- @param #string PlayerUnitCoalition The coalition of the player unit.
-- @param #string PlayerUnitCategory The category of the player unit.
-- @param #string PlayerUnitType The type of the player unit.
-- @param #string TargetUnitName The name of the target unit.
-- @param #string TargetUnitCoalition The coalition of the target unit.
-- @param #string TargetUnitCategory The category of the target unit.
-- @param #string TargetUnitType The type of the target unit.
-- @return #SCORING self
function SCORING:ScoreCSV( PlayerName, ScoreType, ScoreTimes, ScoreAmount, PlayerUnitName, PlayerUnitCoalition, PlayerUnitCategory, PlayerUnitType, TargetUnitName, TargetUnitCoalition, TargetUnitCategory, TargetUnitType )
  --write statistic information to file
  local ScoreTime = self:SecondsToClock( timer.getTime() )
  PlayerName = PlayerName:gsub( '"', '_' )

  if PlayerUnitName and PlayerUnitName ~= '' then
    local PlayerUnit = Unit.getByName( PlayerUnitName )

    if PlayerUnit then
      if not PlayerUnitCategory then
        --PlayerUnitCategory = SCORINGCategory[PlayerUnit:getCategory()]
        PlayerUnitCategory = _SCORINGCategory[PlayerUnit:getDesc().category]
      end

      if not PlayerUnitCoalition then
        PlayerUnitCoalition = _SCORINGCoalition[PlayerUnit:getCoalition()]
      end

      if not PlayerUnitType then
        PlayerUnitType = PlayerUnit:getTypeName()
      end
    else
      PlayerUnitName = ''
      PlayerUnitCategory = ''
      PlayerUnitCoalition = ''
      PlayerUnitType = ''
    end
  else
    PlayerUnitName = ''
    PlayerUnitCategory = ''
    PlayerUnitCoalition = ''
    PlayerUnitType = ''
  end

  if not TargetUnitCoalition then
    TargetUnitCoalition = ''
  end

  if not TargetUnitCategory then
    TargetUnitCategory = ''
  end

  if not TargetUnitType then
    TargetUnitType = ''
  end

  if not TargetUnitName then
    TargetUnitName = ''
  end

  if lfs and io and os then
    self.CSVFile:write(
      '"' .. self.GameName        .. '"' .. ',' ..
      '"' .. self.RunTime         .. '"' .. ',' ..
      ''  .. ScoreTime            .. ''  .. ',' ..
      '"' .. PlayerName           .. '"' .. ',' ..
      '"' .. ScoreType            .. '"' .. ',' ..
      '"' .. PlayerUnitCoalition  .. '"' .. ',' ..
      '"' .. PlayerUnitCategory   .. '"' .. ',' ..
      '"' .. PlayerUnitType       .. '"' .. ',' ..
      '"' .. PlayerUnitName       .. '"' .. ',' ..
      '"' .. TargetUnitCoalition  .. '"' .. ',' ..
      '"' .. TargetUnitCategory   .. '"' .. ',' ..
      '"' .. TargetUnitType       .. '"' .. ',' ..
      '"' .. TargetUnitName       .. '"' .. ',' ..
      ''  .. ScoreTimes           .. ''  .. ',' ..
      ''  .. ScoreAmount
    )

    self.CSVFile:write( "\n" )
  end
end


function SCORING:CloseCSV()
  if lfs and io and os then
    self.CSVFile:close()
  end
end

