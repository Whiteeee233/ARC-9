function SWEP:ShouldLOD()
    if LocalPlayer() == self:GetOwner() then return 0 end

    local dsquared

    if IsValid(self:GetOwner()) then
        dsquared = EyePos():DistToSqr(self:GetOwner():GetPos())
    else
        dsquared = EyePos():DistToSqr(self:GetPos())
    end

    if dsquared >= 25000000 then
        return 2
    elseif dsquared >= 4000000 then
        return 1
    else
        return 0
    end
end

function SWEP:DrawCustomModel(wm, custompos, customang)
    if !wm and !IsValid(self:GetOwner()) then return end
    if !wm and self:GetOwner():IsNPC() then return end
    if custompos then wm = true end

    local mdl = self.VModel
    local lod = 0

    if wm then
        if custompos then
            mdl = self.CModel
        else
            mdl = self.WModel
            lod = self:ShouldLOD()
        end

        if lod >= 2 then
            self:KillModel()
            self:DrawModel()
            return
        end
    end

    if !mdl then
        self:SetupModel(wm, lod, !!custompos)

        mdl = self.VModel

        if wm then
            mdl = self.WModel
            if custompos then
                mdl = self.CModel
            end
        end
    end

    if lod < 2 then
        for _, model in ipairs(mdl) do
            local slottbl = model.slottbl
            local atttbl = self:GetFinalAttTable(slottbl)

            local apos, aang = self:GetAttPos(slottbl, wm, false, false, custompos, customang or Angle(0, 0, 0))

            if model.IsAnimationProxy then
                apos = Vector(0, 0, 0)
                aang = Angle(0, 0, 0)
            end

            model:SetPos(apos)
            model:SetAngles(aang)
            model:SetRenderOrigin(apos)
            model:SetRenderAngles(aang)
            model:SetupBones()

            -- if !wm and atttbl.HoloSight then
            --     self:DoHolosight(model, atttbl)
            -- end

            if !ARC9.PresetCam then
                if !wm and atttbl.RTScope then
                    local active = slottbl == self:GetActiveSightSlotTable()
                    self:DoRTScope(model, atttbl, active)
                elseif wm and atttbl.RTScope then
                    model:SetSubMaterial(atttbl.RTScopeSubmatIndex, "vgui/black")
                end
            end

            if !model.NoDraw then
                model:DrawModel()
            end

            if model.Flare and !self:GetCustomize() then
                if model.Flare.Attachment then
                    local attpos = model:GetAttachment(model.Flare.Attachment)

                    if attpos then
                        self:DrawLightFlare(attpos.Pos, -attpos.Ang:Right(), model.Flare.Color, model.Flare.Size, model.Flare.Focus)
                    else
                        self:DrawLightFlare(apos, aang:Forward(), model.Flare.Color, model.Flare.Size, model.Flare.Focus)
                    end
                else
                    self:DrawLightFlare(apos, aang:Forward(), model.Flare.Color, model.Flare.Size, model.Flare.Focus)
                end
            end

            if atttbl.DrawFunc then
                atttbl.DrawFunc(self, model, wm)
            end
        end

        if wm then
            self:DrawFlashlightsWM()
        else
            self:DrawFlashlightsVM()
        end
    end
end

function SWEP:GetActiveSightSlotTable()
    local sight = self:GetSight() or {}

    return sight.slottbl or {}
end