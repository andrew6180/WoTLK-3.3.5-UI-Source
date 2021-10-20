-- Note: If you're looking to modify any of the actual interface options, you probably want UIOptionsPanels.lua

local blizzardCategories = {};
OPTIONSLIST_BUTTONHEIGHT = 18;

function OptionsFrameCancel_OnClick ()
	--Iterate through registered panels and run their cancel methods in a taint-safe fashion

	for _, category in next, blizzardCategories do
		securecall("pcall", category.cancel, category);
	end
	
	OptionsFrame_Show();
end

function OptionsFrameOkay_OnClick ()
	--Iterate through registered panels and run their okay methods in a taint-safe fashion

	for _, category in next, blizzardCategories do
		securecall("pcall", category.okay, category);
	end
	
	if ( OptionsFrame.gxRestart ) then
		OptionsFrame.gxRestart = nil;
		ConsoleExec("gxRestart");
	end
	
	OptionsFrame_Show();
end

function OptionsFrameDefaults_OnClick ()
	StaticPopup_Show("CONFIRM_RESET_SETTINGS");
end

function OptionsFrame_SetAllToDefaults ()
	--Iterate through registered panels and run their default methods in a taint-safe fashion

	for _, category in next, blizzardCategories do
		securecall("pcall", category.default, category);
	end
	
	--Run the OnShow method of the currently displayed panel so that it can update any values that were changed.
	local displayedFrame = OptionsFramePanelContainer.displayedFrame;
	if ( displayedFrame and displayedFrame.GetScript ) then
		local script = displayedFrame:GetScript("OnShow");
		if ( script ) then
			securecall(script, displayedFrame);
		end
	end
end

function OptionsFrame_SetCurrentToDefaults ()
	local displayedFrame = OptionsFramePanelContainer.displayedFrame;
	
	if ( not displayedFrame or not displayedFrame.default ) then
		return;
	end
	
	securecall("pcall", displayedFrame.default, displayedFrame);
	if ( displayedFrame and displayedFrame.GetScript ) then
		local script = displayedFrame:GetScript("OnShow");
		if ( script ) then
			securecall(script, displayedFrame);
		end
	end
end

function OptionsFrame_OnLoad (self)
	--Make sure all the UVars get their default values set, since systems that require them to be defined will be loaded before anything in UIOptionsPanels
	self:RegisterEvent("SET_GLUE_SCREEN");
end

function OptionsFrame_OnShow ()
	--Refresh the two category lists and display the "Controls" group of options if nothing is selected.
	OptionsCategoryList_Update();
	if ( not OptionsFramePanelContainer.displayedFrame ) then
		OptionsFrameCategories.buttons[1]:Click();
	end
	
	if ( not OptionsFrame.videoQuality ) then
		-- First time we've shown the frame. Fix the Video Quality settings.
		OptionsFrame.videoQuality = VideoOptionsPanel_GetVideoQuality();
		VideoOptionsPanel_SetVideoQualityLabels(OptionsFrame.videoQuality);
	end
end

function OptionsFrame_OnHide ()
	--Yay for playing sounds
	PlaySound("gsTitleOptionExit");
	
	local quality = VideoOptionsPanel_GetVideoQuality();
	VideoOptionsPanel_SetVideoQualityLabels(quality);
end

function OptionsFrame_OnEvent (self, event, ...)
	self:UnregisterEvent(event);
end

function OptionsFrame_Show ()
	if ( OptionsFrame:IsShown() ) then
		OptionsFrame:Hide();
	else
		OptionsFrame:Show();
	end
end

function OptionsFrame_OpenToFrame (frame)
	local frameName;
	if ( type(frame) == "string" ) then
		frameName = frame;
		frame = nil;
	end
	
	assert(frameName or frame, 'Usage: OptionsFrame_OpenToFrame("categoryName" or frame)');
	
	local blizzardElement, elementToDisplay
	
	for i, element in next, blizzardCategories do
		if ( element == frame or (frameName and element.name and element.name == frameName) ) then
			elementToDisplay = element;
			blizzardElement = true;
			break;
		end
	end
		
	if ( not elementToDisplay ) then
		return;
	end
	
	local buttons = OptionsFrameCategories.buttons
	for i, button in next, buttons do
		if ( button.element == elementToDisplay ) then
			button:Click();
		elseif ( elementToDisplay.parent and button.element and (button.element.name == elementToDisplay.parent and button.element.collapsed) ) then
			button.toggle:Click();
		end
	end
	
	if ( not OptionsFrame:IsShown() ) then
		OptionsFrame_Show();
	end
end

function OptionsList_OnLoad (categoryFrame)
	local name = categoryFrame:GetName();
	
	--Setup random things!
	categoryFrame.scrollBar = getglobal(name .. "ListScrollBar");
	categoryFrame:SetBackdropBorderColor(.6, .6, .6, 1);
	getglobal(name.."Bottom"):SetVertexColor(.66, .66, .66);
	
	--Create buttons for scrolling
	local buttons = {};
	local button = CreateFrame("BUTTON", name .. "Button1", categoryFrame, "OptionsButtonTemplate");
	button:SetPoint("TOPLEFT", categoryFrame, 0, -8);
	categoryFrame.buttonHeight = button:GetHeight();
	tinsert(buttons, button);
	
	local maxButtons = (categoryFrame:GetHeight() - 8) / categoryFrame.buttonHeight;
	for i = 2, maxButtons do
		button = CreateFrame("BUTTON", name .. "Button" .. i, categoryFrame, "OptionsButtonTemplate");
		button:SetPoint("TOPLEFT", buttons[#buttons], "BOTTOMLEFT");
		tinsert(buttons, button);
	end
	
	categoryFrame.buttons = buttons;	
end

--Table to reuse! Yay reuse!
local displayedElements = {}

function OptionsCategoryList_Update ()
	--Redraw the scroll lists
	local offset = FauxScrollFrame_GetOffset(OptionsFrameCategoriesList);
	local buttons = OptionsFrameCategories.buttons;
	local element;
	
	for i, element in next, displayedElements do
		displayedElements[i] = nil;
	end
	
	for i, element in next, blizzardCategories do
		if ( not element.hidden ) then
			tinsert(displayedElements, element);
		end
	end
	
	local numButtons = #buttons;
	local numCategories = #displayedElements;
	
	if ( numCategories > numButtons and ( not OptionsFrameCategoriesList:IsShown() ) ) then
		OptionsList_DisplayScrollBar(OptionsFrameCategories);
	elseif ( numCategories <= numButtons and ( OptionsFrameCategoriesList:IsShown() ) ) then
		OptionsList_HideScrollBar(OptionsFrameCategories);	
	end
	
	FauxScrollFrame_Update(OptionsFrameCategoriesList, numCategories, numButtons, buttons[1]:GetHeight());
	
	local selection = OptionsFrameCategories.selection;
	if ( selection ) then
		-- Store the currently selected element and clear all the buttons, we're redrawing.
		OptionsList_ClearSelection(OptionsFrameCategories, OptionsFrameCategories.buttons);
	end
		
	
	for i = 1, numButtons do
		element = displayedElements[i + offset];
		if ( not element ) then
			OptionsList_HideButton(buttons[i]);
		else
			OptionsList_DisplayButton(buttons[i], element);
			
			if ( selection ) and ( selection == element ) and ( not OptionsFrameCategories.selection ) then
				OptionsList_SelectButton(OptionsFrameCategories, buttons[i]);
			end
		end
		
	end
	
	if ( selection ) then
		-- If there was a selected element before we cleared the button highlights, restore it, 'cause we're done.
		-- Note: This theoretically might already have been done by InterfaceOptionsList_SelectButton, but in the event that the selected button hasn't been drawn, this is still necessary.
		OptionsFrameCategories.selection = selection;
	end
end

function OptionsList_DisplayScrollBar (frame)
	local list = getglobal(frame:GetName() .. "List");
	list:Show();

	local listWidth = list:GetWidth();
	
	for _, button in next, frame.buttons do
		button:SetWidth(button:GetWidth() - listWidth);
	end
end

function OptionsList_HideScrollBar (frame)
	local list = getglobal(frame:GetName() .. "List");
	list:Hide();
	
	local listWidth = list:GetWidth();
	
	for _, button in next, frame.buttons do
		button:SetWidth(button:GetWidth() + listWidth);
	end
end

function OptionsList_HideButton (button)
	-- Sparse for now, who knows what will end up here?
	button:Hide();
end

function OptionsList_DisplayButton (button, element)
	-- Do display things
	button:Show();
	button.element = element;
	
	if (element.parent) then
		button:SetNormalFontObject(GlueFontHighlightSmall);
		button:SetHighlightFontObject(GlueFontHighlightSmall);
		button.text:SetPoint("LEFT", 16, 2);
	else
		button:SetNormalFontObject(GlueFontNormal);
		button:SetHighlightFontObject(GlueFontHighlight);
		button.text:SetPoint("LEFT", 8, 2);
	end
	button.text:SetText(element.name);
	
	if (element.hasChildren) then
		if (element.collapsed) then
			button.toggle:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-UP");
			button.toggle:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-DOWN");
		else
			button.toggle:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-UP");
			button.toggle:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-DOWN");		
		end
		button.toggle:Show();
	else
		button.toggle:Hide();
	end
end

function OptionsListButton_OnClick (mouseButton, button)
	if ( mouseButton == "RightButton" ) then
		if ( button.element.hasChildren ) then
			button.toggle:Click();
		end
		return;
	end
	
	local parent = button:GetParent();
	local buttons = parent.buttons;
	
	OptionsList_ClearSelection(OptionsFrameCategories, OptionsFrameCategories.buttons);
	OptionsList_SelectButton(parent, button);
	
	OptionsList_DisplayFrame(button.element);
end

function OptionsList_DisplayFrame (frame)	
	if ( OptionsFramePanelContainer.displayedFrame ) then
		OptionsFramePanelContainer.displayedFrame:Hide();
	end
	
	OptionsFramePanelContainer.displayedFrame = frame;
	
	frame:SetParent(OptionsFramePanelContainer);
	frame:ClearAllPoints();
	frame:SetPoint("TOPLEFT", OptionsFramePanelContainer, "TOPLEFT");
	frame:SetPoint("BOTTOMRIGHT", OptionsFramePanelContainer, "BOTTOMRIGHT");
	frame:Show();
end

function OptionsList_ClearSelection (listFrame, buttons)
	for _, button in next, buttons do
		button:UnlockHighlight();
	end
	
	listFrame.selection = nil;
end

function OptionsList_SelectButton (listFrame, button)
	button:LockHighlight()
	if ( not listFrame ) then
		debugbreak();
	end

	listFrame.selection = button.element;
end

function OptionsFrame_AddCategory (frame)
	local parent = frame.parent;
	if ( parent ) then
		for i = 1, #blizzardCategories do
			if ( blizzardCategories[i].name == parent ) then
				if ( blizzardCategories[i].hasChildren ) then
					frame.hidden = ( blizzardCategories[i].collapsed );
				else
					frame.hidden = true;
					blizzardCategories[i].hasChildren = true;
					blizzardCategories[i].collapsed = true;
				end
				tinsert(blizzardCategories, i + 1, frame);
				OptionsCategoryList_Update();
				return;
			end
		end
	end
	
	tinsert(blizzardCategories, frame);
	OptionsCategoryList_Update();
end

function OptionsFrame_ToggleSubCategories (button)
	local element = button:GetParent().element;
	
	element.collapsed = not element.collapsed;
	local collapsed = element.collapsed;
	
	for _, category in next, blizzardCategories do
		if ( category.parent == element.name ) then
			if ( collapsed ) then
				category.hidden = true;
			else
				category.hidden = false;
			end
		end
	end
	
	OptionsCategoryList_Update();
end

function BlizzardOptionsPanel_ResetControl (control)
	if ( control.value and control.currValue and ( control.value ~= control.currValue ) ) then
		control:SetValue(control.currValue);
	end
end

function BlizzardOptionsPanel_DefaultControl (control)
	if ( control:GetValue() ~= control.defaultValue ) then
		control:SetValue(control.defaultValue);
	end
end

function BlizzardOptionsPanel_UpdateCurrentControlValue (control)
	control.currValue = control.value;
end

local function BlizzardOptionsPanel_Okay (self)
	for _, control in next, self.controls do
		securecall(BlizzardOptionsPanel_UpdateCurrentControlValue, control);
	end
end

local function BlizzardOptionsPanel_Cancel (self)
	for _, control in next, self.controls do
		securecall(BlizzardOptionsPanel_ResetControl, control);
	end
end

local function BlizzardOptionsPanel_Default (self)
	for _, control in next, self.controls do
		securecall(BlizzardOptionsPanel_DefaultControl, control);
	end
end

function OptionsFrame_SetupBlizzardPanel (frame)
	frame.okay = BlizzardOptionsPanel_Okay;
	frame.cancel = BlizzardOptionsPanel_Cancel;
	frame.default = BlizzardOptionsPanel_Default;
end

function OptionsFrame_DisableSlider(slider)
	slider.disabled = true;
	local name = slider:GetName();
	getmetatable(slider).__index.Disable(slider);
	getglobal(name.."Text"):SetVertexColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
	getglobal(name.."Low"):SetVertexColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
	getglobal(name.."High"):SetVertexColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
end

function OptionsFrame_EnableSlider(slider)
	slider.disabled = nil;
	local name = slider:GetName();
	getmetatable(slider).__index.Enable(slider);
	getglobal(name.."Text"):SetVertexColor(NORMAL_FONT_COLOR.r , NORMAL_FONT_COLOR.g , NORMAL_FONT_COLOR.b);
	getglobal(name.."Low"):SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
	getglobal(name.."High"):SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
end
