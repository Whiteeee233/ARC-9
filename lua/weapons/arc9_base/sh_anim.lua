function SWEP:PlayAnimation(anim, mult, lock)
    mult = mult or 1
    lock = lock or false
    anim = self:TranslateAnimation(anim)

    mult = self:RunHook("Hook_TranslateAnimSpeed", {mult = mult, anim = anim}).Mult or mult

    if !self:HasAnimation(anim) then return 0 end

    if self:RunHook("Hook_BlockAnimation", anim) == true then return 0 end

    local mdl = self:GetVM()

    if !IsValid(mdl) then return 0 end

    local animation = self:GetAnimationEntry(anim)

    local source = self:RandomChoice(animation.Source)

    if animation.RareSource then
        if util.SharedRandom("ARC9_raresource", 0, 1) <= (animation.RareSourceChance or 0.01) then
            source = self:RandomChoice(animation.RareSource)
        end
    end

    local seq = 0

    if animation.ProxyAnimation then
        if CLIENT then
            mdl = animation.Model
        else
            mdl = ents.Create("prop_physics")
            mdl:SetModel(animation.ModelName)
        end

        self:SetSequenceProxy(animation.Address or 0)

        if !IsValid(mdl) then return 0 end

        seq = mdl:LookupSequence(source)

        if seq == -1 then return 0 end
    else
        seq = mdl:LookupSequence(source)

        if seq == -1 then return 0 end

        self:SetSequenceProxy(0)
    end

    local time = animation.Time or mdl:SequenceDuration(seq)

    mult = mult * (animation.Mult or 1)

    local tmult = 1

    tmult = (mdl:SequenceDuration(seq) / time) / mult

    if animation.Reverse then
        tmult = tmult * -1
    end

    if animation.ProxyAnimation then
        mdl:SetSequence(seq)
        mdl:SetCycle(0)
    else
        mdl:SendViewModelMatchingSequence(seq)
        mdl:SetPlaybackRate(tmult)
    end

    self:SetSequenceIndex(seq or 0)
    self:SetSequenceSpeed((1 / time) / mult)
    self:SetSequenceCycle(0)

    mult = math.abs(mult)

    if animation.EjectAt then
        self:SetTimer(animation.EjectAt * mult, function()
            self:DoEject()
        end)
    end

    local minprogress = animation.MinProgress or 0.8
    minprogress = math.min(minprogress, 1)

    if animation.RestoreAmmo then
        self:SetTimer(time * mult * minprogress, function()
            self:RestoreClip(animation.RestoreAmmo)
        end)
    end

    if animation.EventTable then
        self:PlaySoundTable(animation.EventTable or animation.SoundTable, mult)
    end

    self:SetHideBoneIndex(animation.HideBoneIndex or 0)

    if animation.IKTimeLine then
        self:SetIKAnimation(anim)
        self:SetIKTimeLineStart(CurTime())
        self:SetIKTime(time * mult)
    end

    if lock then
        if !animation.FireASAP then minprogress = 1 end

        self:SetAnimLockTime(CurTime() + (time * mult * minprogress))
    else
        self:SetAnimLockTime(CurTime())
    end

    if !animation.NoIdle then
        self:SetNextIdle(CurTime() + (time * mult))
    else
        self:SetNextIdle(math.huge)
    end

    if animation.PoseParamChanges then
        for i, k in pairs(animation.PoseParamChanges) do
            self.PoseParamState[i] = k
        end
    end

    self:SetFinishFiremodeAnimTime(CurTime())

    if SERVER and animation.ProxyAnimation then
        SafeRemoveEntity(mdl)
    end

    return time * mult
end

function SWEP:GetAnimationProxyModel(wm)
    local mdl
    if SERVER then
        local atttbl = self:GetFinalAttTableFromAddress(self:GetSequenceProxy())
        local modelname = atttbl.Model
        mdl = ents.Create("prop_physics")
        mdl:SetModel(modelname)
    else
        local slottbl = self:LocateSlotFromAddress(self:GetSequenceProxy())

        if !slottbl then return end

        if wm then
            mdl = slottbl.WModel
        else
            mdl = slottbl.VModel
        end
    end

    return mdl
end

function SWEP:IdleAtEndOfAnimation()
    local mdl = self:GetVM()

    local cyc
    local duration
    local rate

    if self:GetSequenceProxy() == 0 then
        cyc = mdl:GetCycle()
        duration = mdl:SequenceDuration()
        rate = mdl:GetPlaybackRate()
    else
        mdl = self:GetAnimationProxyModel()

        cyc = self:GetSequenceCycle()
        duration = mdl:SequenceDuration(self:GetSequenceIndex())
        rate = self:GetSequenceSpeed()

        if SERVER then
            SafeRemoveEntity(mdl)
        end
    end

    local time = (1 - cyc) * (duration / rate)

    self:SetNextIdle(CurTime() + time)
end

function SWEP:Idle()
    if self:GetPrimedAttack() then return end
    if self:GetSafe() then return end

    self:PlayAnimation("idle")
end

SWEP.PoseParamState = {}

function SWEP:DoPoseParams()
    local vm = self:GetVM()

    if !vm or !IsValid(vm) then return end

    for i, k in pairs(self.PoseParamState) do
        vm:SetPoseParameter(i, k)
    end
end

function SWEP:ThinkAnimation()
    if CLIENT and self:GetSequenceProxy() != 0 then
        for _, wm in ipairs({true, false}) do
            local mdl = self:GetAnimationProxyModel(wm)

            if !IsValid(mdl) then continue end

            mdl:SetSequence(self:GetSequenceIndex())
            mdl:SetCycle(self:GetSequenceCycle())

            if self:GetSequenceProxy() == self.LHIKModelAddress then
                local lhik_mdl

                if wm then
                    lhik_mdl = self.LHIKModelWM
                else
                    lhik_mdl = self.LHIKModel
                end

                lhik_mdl:SetSequence(self:GetSequenceIndex())
                lhik_mdl:SetCycle(self:GetSequenceCycle())
            end

            if self:GetSequenceProxy() == self.RHIKModelAddress then
                local rhik_mdl

                if wm then
                    rhik_mdl = self.RHIKModelWM
                else
                    rhik_mdl = self.RHIKModel
                end

                rhik_mdl:SetSequence(self:GetSequenceIndex())
                rhik_mdl:SetCycle(self:GetSequenceCycle())
            end
        end
    end

    local mult = self:GetSequenceSpeed()

    self:SetSequenceCycle(self:GetSequenceCycle() + (FrameTime() * mult))
end