--- **AI (Release 2.1)** -- Management of target designation.
--
-- --![Banner Image](..\Presentations\AI_DESIGNATE\CARGO.JPG)
--
-- ===
--
-- @module AI_Designate


do -- AI_DESIGNATE

  --- @type AI_DESIGNATE
  -- @extends Core.Fsm#FSM_PROCESS

  ---
  -- 
  -- @field #AI_DESIGNATE AI_DESIGNATE
  -- 
  AI_DESIGNATE = {
    ClassName = "AI_DESIGNATE",
  }

  --- AI_DESIGNATE Constructor. This class is an abstract class and should not be instantiated.
  -- @param #AI_DESIGNATE self
  -- @param Functional.Detection#DETECTION_BASE Detection
  -- @param Core.Set#SET_GROUP GroupSet The set of groups to designate for.
  -- @return #AI_DESIGNATE
  function AI_DESIGNATE:New( Detection, GroupSet )
  
    local self = BASE:Inherit( self, FSM:New() ) -- #AI_DESIGNATE
    self:F( { Detection } )
  
    self:SetStartState( "Designating" )
    self:AddTransition( "*", "Detect", "*" )
    self:AddTransition( "*", "Designate", "*" )
    self:AddTransition( "*", "Status", "*" )
  
    self.Detection = Detection
    self.GroupSet = GroupSet
    
    self.Detection:__Start( 2 )

    self.GroupSet:ForEachGroup(
      --- @param Wrapper.Group#GROUP GroupReport
      function( GroupReport )
        GroupReport:SetState( GroupReport, "DesignateMenu", MENU_GROUP:New( GroupReport, "Designate Targets" ) )
      end
    )
    
    return self
  end

  --- 
  -- @param #AI_DESIGNATE self
  -- @return #AI_DESIGNATE
  function AI_DESIGNATE:onafterDetect()
    
    self:__Detect( -60 )
    
    self.GroupSet:ForEachGroup(
    
      --- @param Wrapper.Group#GROUP GroupReport
      function( GroupReport )
      
        local DesignateMenu = GroupReport:GetState( GroupReport, "DesignateMenu" ) -- Core.Menu#MENU_GROUP
        DesignateMenu:RemoveSubMenus()
        
      
        local DetectedItems = self.Detection:GetDetectedItems()
        
        for Index, DetectedItemData in pairs( DetectedItems ) do
          
          local DetectedReport = self.Detection:DetectedItemReportSummary( Index )
          
          GroupReport:MessageToAll( DetectedReport,15,"Detected")
          
          MENU_GROUP_COMMAND:New(
            GroupReport, 
            DetectedReport,
            DesignateMenu,
            self.MenuDesignate,
            self,
            Index
          )
        end
      end
    )
  
    return self
  end
  
  --- 
  -- @param #AI_DESIGNATE self
  function AI_DESIGNATE:MenuDesignate( Index )

    self:E("in designate")

    self:__Designate( 1, Index )    
  end

  --- 
  -- @param #AI_DESIGNATE self
  -- @return #AI_DESIGNATE
  function AI_DESIGNATE:onafterDesignate( From, Event, To, Index )
  

    local TargetSetUnit = self.Detection:GetDetectedSet( Index )
  
    TargetSetUnit:ForEachUnit(
      --- @param Wrapper.Unit#UNIT SmokeUnit
      function( SmokeUnit )
        self:E("In procedure")
        --if math.random( 1, ( 100 * TargetSetUnit:Count() ) / 100 ) <= 100 then
          SCHEDULER:New( self,
            function()
              if SmokeUnit:IsAlive() then
                SmokeUnit:Smoke( SMOKECOLOR.Red, 150 )
              end
            end, {}, math.random( 10, 60 ) 
          )
        --end
      end
    )
    

  end

end


