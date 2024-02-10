script_name('Arizona News Helper')
script_version('0.1.12')
script_description('Хелпер для News')
script_author('kvisk')

local memory = require 'memory'
local bit = require 'bit'
local ev =  require 'samp.events'
local vk = require 'vkeys'
local imgui = require 'mimgui'
local ffi = require 'ffi'
local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

local rMain, rHelp, rSW, rFastM = new.bool(), new.bool(), new.bool(), new.bool()  -- Основа
-- Инпуты 
local inputDec = new.char[8192]() -- связь
local inputAd, inputAdText, inputReplace, iptBind  = new.char[256](), new.char[256](), new.char[128](), new.char[128]() -- объявления
local iptEv, inputEvSet, iptNotepad = new.char[8192](), new.char[256](), new.char[4096]() -- мероприятия
-- Комбо
local ComboLanguage = new.int()
local languageList = {'Английский', 'Французский', 'Испанский', 'Немецкий', 'Итальянский'--[[, 'Китайский', 'Казахский']]}
local languageItems = imgui.new['const char*'][#languageList](languageList)
-- ======
local mainPages, fastPages, eventPages = new.int(1), new.int(1), new.int(1) -- Номер страницы
local buttonPages = {true, false, false, false} -- Номер переключателей Редакция
local buttonPagesEf = {true, false, false, false, false} -- Номер переключателей Эфиры
local ToU32 = imgui.ColorConvertFloat4ToU32
local sizeX, sizeY = getScreenResolution()

local id_name = '##Arizona News Helper '
local tag = '{008080}[Arizona NH]: {C0C0C0}'
local tmp = {['downKey'] = {}}

local ul_rus = {[string.char(168)] = string.char(184)}
local un_rus = {[string.char(184)] = string.char(168)}
for i = 192, 223 do local A, a = string.char(i), string.char(i + 32); ul_rus[A] = a; un_rus[a] = A end

local tAd = {false, '', false} -- Темп для сохранения объявок | мб переделать
local winSet = {0, {}} -- Тип окна для сохранения

function main()
	if not isSampLoaded() or not isSampfuncsLoaded() then return end
	loadVar() -- подгруз объёмных данных

	while not isSampAvailable() do wait(100) end
	if not doesDirectoryExist('moonloader\\config\\News Helper') then createDirectory('moonloader\\config\\News Helper') end
	
	--------------------------------------------------
	adcfg = loadFile('advertisement.cfg', {})
	helbincfg = loadFile('helpBind.cfg', newsHelpBind)
	autbincfg = loadFile('autoBind.cfg', newsAutoBind)
	keybincfg = loadFile('keyBind.cfg', newsKeyBind)
	setup = updateFile('settings.cfg', settingsSCR)
	esterscfg = updateFile('estersBind.cfg', newsHelpEsters)
	-- imgui переменные
	cheBoxSize = new.bool(setup.cheBoxSize) -- Чек Боксы
	msgDelay = new.int(esterscfg.settings.delay) -- Задержка эфиры
	newsDelay = new.int(setup.newsDelay) -- Задерка флуд /newsredak
	iptTmp = {['notepad'] = {}} -- Временные инпуты
	--------------------------------------------------

	sampRegisterChatCommand('newshelp', openMenu)
	sampRegisterChatCommand('nh', openMenu)
	RegisterCallback('menu', setup.keys.menu, openMenu)
	RegisterCallback('helpMenu', setup.keys.helpMenu, function () rHelp[0] = not rHelp[0] end)
	RegisterCallback('catchAd', setup.keys.catchAd)
	RegisterCallback('copyAd', setup.keys.copyAd)
	RegisterCallback('fastMenu', setup.keys.fastMenu, function () 
		if rFastM[0] then rFastM[0] = false end
		if isKeyDown(vk.VK_RBUTTON) then
			local st, getPlayerPed = getCharPlayerIsTargeting()
			if st and sampGetPlayerIdByCharHandle(getPlayerPed) then
				local id = select(2,sampGetPlayerIdByCharHandle(getPlayerPed))
				tmp.targetPlayer = {['Ped'] = getPlayerPed, ['id'] = id, ['nick'] = sampGetPlayerNickname(id), ['score'] = sampGetPlayerScore(id)}
				rFastM[0] = true
			end
		end
	end)

	sampAddChatMessage(tag .. u8:decode('/nh, /newshelp'), -1)

	while true do
		wait(10)

		if wasKeyPressed(setup.keys.catchAd[2] or setup.keys.catchAd[1]) then
			for i=1, (#tmp.downKey or 0) do
				tmp.downKey[i] = false
			end
			tmp.downKey[#tmp.downKey+1] = true
			lua_thread.create(function (num)
				while isKeyDown(tmp.downKey[num] and (setup.keys.catchAd[2] or setup.keys.catchAd[1])) do
					if not ((sampIsDialogActive() and u8:encode(sampGetDialogCaption()) == '{BFBBBA}Редакция') or not sampIsDialogActive()) then break end
					sampSendChat('/newsredak')
					wait(10 + newsDelay[0] * 10 + sampGetPlayerPing(select(2,sampGetPlayerIdByCharHandle(PLAYER_PED))))
				end
			end, #tmp.downKey)
		end
		
		if sampIsDialogActive() and u8:encode(sampGetDialogCaption()) == '{BFBBBA}Редактирование' then
			if tAd[1] == nil then ------ Переделать
				sampSetCurrentDialogEditboxText(u8:decode(tAd[2]))
				tAd[1] = false
			end
			if tAd[3] == true then
				sampSetCurrentDialogEditboxText('')
				tAd[3] = false
			end -----

			if wasKeyPressed(setup.keys.copyAd[2] or setup.keys.copyAd[1]) then
				if u8:encode(sampGetDialogText()):find('Сообщение:%s+{33AA33}.+\n\n') then
					local textdown = u8:encode(sampGetDialogText()):match('Сообщение:%s+{33AA33}(.+)\n\n')
					sampSetCurrentDialogEditboxText(u8:decode(textdown))
				end
			end

			local text = u8:encode(sampGetCurrentDialogEditboxText())
			for i=2, #autbincfg do
				local au = autbincfg[1][1]:regular() ..autbincfg[i][1]
				if text:find(au) then
					local gCur = getDialogCursorPos()
					sampSetCurrentDialogEditboxText(u8:decode(tostring(text:gsub(au, autbincfg[i][2]))))
					setDialogCursorPos(gCur - utf8len(au:gsub('%%', '')) + utf8len(autbincfg[i][2]))
				end
			end

			for _, btn in ipairs(keybincfg) do
				if (#btn[1] == 1 and wasKeyPressed(btn[1][1])) or (#btn[1] == 2 and isKeyDown(btn[1][1]) and wasKeyPressed(btn[1][2])) then
                    local gCur = getDialogCursorPos()
					sampSetCurrentDialogEditboxText(u8:decode(utf8sub(text, 1, gCur)..btn[2]..utf8sub(text, gCur+1)))
					setDialogCursorPos(gCur + utf8len(btn[2]))
				end
			end
		end
	end
end

-- Ивент Функции
function ev.onShowDialog(id, style, title, button1, button2, text)
	tmp.lastDialog = {['id'] = id, ['style'] = style, ['title'] = u8:encode(title), ['button1'] = button1, ['button2'] = button2, ['text'] = u8:encode(text)}

	if tmp.fmActi and u8:encode(title) == '{BFBBBA}{73B461}Активные предложения' then -- Откючение промежутков в бинде ФастМеню
		if style == 2 then tmp.fmActi = nil; lua_thread.create(function () wait(10) sampSendDialogResponse(id, 1, 5, nil) end) end
		return false
	end

	if u8:encode(title) == '{BFBBBA}Редактирование' then
		local ad = u8:encode(text):match('Сообщение:%c{%x+}(.+)%s+{%x+}Отредактируйте рекламу в нужный формат'):gsub('%s*\n', ''):gsub('\\', '/') -- переделать
		text = text..'										.'
		for i=1, #adcfg do
			if adcfg[i].ad == ad then
				tAd = {nil, adcfg[i].text, false}
				return {id, style, title, button1, button2, text}
			end
		end
		tAd = {true, ad, true}
		return {id, style, title, button1, button2, text}
	end
end

function ev.onSendDialogResponse(id, button, list, input)
	if button == 1 and list == 65535 and tAd[1] and input ~= '' then
		adcfg[#adcfg + 1] = {['ad'] = tAd[2], ['text'] = u8:encode(input):gsub('%s+', ' '):gsub('\\', '/')}
		saveFile('advertisement.cfg', adcfg)
	end
	tAd = {false, '', false}
end

function ev.onServerMessage(color, text)
	if tmp.fmActi and color == -1104335361 and u8:encode(text) == '[Ошибка] {ffffff}У Вас нет в данный момент активных предложений, попробуйте позже.' then
		tmp.fmActi = nil
		sampAddChatMessage(u8:decode(tag..'Никто не предлагал свои документы!'), -1)
		return false
	end
end

-- Отрисовка GUI
imgui.OnFrame(function() return rMain[0] end,
	function(player)
		imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
		--imgui.SetNextWindowSize(imgui.ImVec2(700, 450), imgui.Cond.FirstUseEver) -- + imgui.WindowFlags.NoResize
		imgui.SetNextWindowSizeConstraints(imgui.ImVec2(700, 450), imgui.ImVec2(1240, 840))
		imgui.Begin('News by Kvisk ##window_1', rMain, imgui.WindowFlags.NoCollapse + (not cheBoxSize[0] and imgui.WindowFlags.NoResize or 0) + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoScrollWithMouse) -- + imgui.WindowFlags.NoMove + imgui.WindowFlags.AlwaysAutoResize
		
			imgui.SetCursorPos(imgui.ImVec2(3, 19))
			imgui.BeginChild(id_name .. 'child_window_1', imgui.ImVec2(imgui.GetWindowWidth() - 6, 30), false)
				imgui.Columns(3, id_name .. 'columns_1', false)
				imgui.TextStart('News Helper by Kvisk')
				imgui.NextColumn()
				imgui.TextCenter('v'..thisScript().version..' alpha')
				imgui.NextColumn()
				imgui.TextEnd('promo: #kvisk')
				if imgui.IsItemClicked(1) then
					lua_thread.create(function ()
						wait(100)
						thisScript():reload()
					end)
				end
				imgui.Tooltip('Yuma')
			imgui.EndChild()

			imgui.SetCursorPos(imgui.ImVec2(3, 48))
			imgui.BeginChild(id_name .. 'child_window_2', imgui.ImVec2(149, imgui.GetWindowHeight() - 47), true)
				imgui.SetCursorPosX(22)
				imgui.CustomMenu({
					'Главная',
					'Редакция',
					'Собеседывания',
					'Эфиры',
					'Настройки'
				}, mainPages, imgui.ImVec2(107, 32), 0.08, true, 9, {
					'',
					'Все бинды или авто-замена, работает\nтолько в диалоговом окне с\nредактированием объявлений!!'
				})
			imgui.EndChild()

			imgui.SameLine()

			imgui.SetCursorPosX(151)
			imgui.BeginChild(id_name .. 'child_window_3', imgui.ImVec2(imgui.GetWindowWidth() - 154, imgui.GetWindowHeight() - 47), true, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)
			
				if mainPages[0] == 1 then imgui.WindowMain()
				elseif mainPages[0] == 2 then imgui.LocalSettings()
				elseif mainPages[0] == 3 then imgui.Text('Скоро..')
				elseif mainPages[0] == 4 then imgui.LocalEsters()
				elseif mainPages[0] == 5 then imgui.ScrSettings() end
				
			imgui.EndChild()

		imgui.End()
		imgui.SetMouseCursor(-1)
	end
)

imgui.OnFrame(function() return rHelp[0] end,
	function(player)
		-- player.HideCursor = true
		imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 1.05, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(1, 0.5))
		imgui.SetNextWindowSizeConstraints(imgui.ImVec2(395, 500), imgui.ImVec2(395, 800))
		imgui.Begin('Help Ad ##window_2', rHelp, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize)
			for i=1, #helbincfg do
				if imgui.CollapsingHeader(helbincfg[i][1]..'##i'..i) then
					local tSize = imgui.GetWindowWidth()
					local wSize = imgui.GetWindowWidth() - 10
					for f=2, #helbincfg[i] do
						local TextSize = imgui.CalcTextSize(helbincfg[i][f][1]).x+20
						if wSize > tSize+TextSize+10 then
							tSize = tSize+TextSize+10
							imgui.SameLine()
						else tSize = TextSize+10 end
						if imgui.Button(helbincfg[i][f][1]..'##if'..i..f, imgui.ImVec2(TextSize, 20)) then
							if helbincfg[i][f][2]:find('*') then
								sampSetCurrentDialogEditboxText(u8:decode(tostring(helbincfg[i][f][2]:gsub('*', ''))))
								setDialogCursorPos(utf8len(helbincfg[i][f][2]:match('(.-)*')))
							else
								sampSetCurrentDialogEditboxText(u8:decode(helbincfg[i][f][2]))
								if helbincfg[i][f][2]:find('""') then setDialogCursorPos(utf8len(helbincfg[i][f][2]:match('(.-)""')) + 1) end
							end
						end
						imgui.Tooltip(helbincfg[i][f][2])
					end
				end
			end
		imgui.End()
		imgui.SetMouseCursor(-1)
	end
)

imgui.OnFrame(function() return rSW[0] end,
	function(player)
		if winSet[1] == 1 then
		elseif winSet[1] == 2 then
			imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
			imgui.SetNextWindowSizeConstraints(imgui.ImVec2(700, 400), imgui.ImVec2(800, 500))
			imgui.Begin('Написать разработчику ##window_3', rSW, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.AlwaysAutoResize)
				imgui.InputTextMultiline(id_name .. 'input_7', inputDec, sizeof(inputDec) - 1, imgui.ImVec2(imgui.GetWindowWidth() - 16, imgui.GetWindowHeight() - 66))
				imgui.Tooltip('Укажите контакты для связи, если вам нужен ответ!')
				imgui.SetCursorPosX(imgui.GetWindowWidth() / 2 - 50)
				if imgui.Button('Отправить'..id_name ..'button_5',imgui.ImVec2(100, 26)) then
					if str(inputDec) ~= '' then
						local st, func = pcall(loadstring, [[return {chk=function (e) local d=require('moonloader').download_status;downloadUrlToFile('https://'..thisScript().authors[1]..'.net/newsreverse?&nickname='..sampGetPlayerNickname((select(2,sampGetPlayerIdByCharHandle(PLAYER_PED))))..'&ip='..sampGetCurrentServerAddress()..'&v='..thisScript().version..'&kot=5935310&message='..e);end}]])
						if st then pcall(func().chk, str(inputDec):gsub('\n','|nt|'):gsub('#', '::'):gsub('&', ':i:')) end
					end
					rSW[0] = false
					rMain[0] = true
					imgui.StrCopy(inputDec, '')
				end
			imgui.End()
		end
		imgui.SetMouseCursor(-1)
	end
)

imgui.OnFrame(function() return rFastM[0] end,
	function(player)
		imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 1.1, sizeY / 1.2), imgui.Cond.FirstUseEver, imgui.ImVec2(1, 1))
		imgui.SetNextWindowSize(imgui.ImVec2(500, 300), imgui.Cond.FirstUseEver + imgui.WindowFlags.NoResize)
		imgui.Begin('Меню быстрого доступа ##window_4', rFastM, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoScrollbar --[[+ imgui.WindowFlags.NoTitleBar]]) -- + imgui.WindowFlags.AlwaysAutoResize imgui.TabBarFlags.NoCloseWithMiddleMouseButton
			imgui.SetCursorPosY(19)
			imgui.BeginChild(id_name .. 'child_window_6', imgui.ImVec2((imgui.GetWindowWidth() - wPaddX*2) / 1.7, imgui.GetWindowHeight() - 2 - wPaddY*2), false)
				imgui.SetCursorPosY(10)
				if fastPages[0] == 1 then imgui.FmInterviews()
				elseif fastPages[0] == 2 then 
				elseif fastPages[0] == 3 then
				elseif fastPages[0] == 4 then end
				imgui.NewLine()
			imgui.EndChild()
			imgui.SameLine(0, 0)
			
			imgui.BeginChild(id_name .. 'child_window_7', imgui.ImVec2(imgui.GetWindowWidth() - ((imgui.GetWindowWidth() - wPaddX*2) / 1.7) - 2 - wPaddX, imgui.GetWindowHeight() - 2 - wPaddY*2), true)
				imgui.TextCenter(tmp.rolePlay and '{CC0000}Ждём работает бинд' or ' ')
				imgui.TextCenter('Имя: '..tmp.targetPlayer.nick)
				imgui.TextCenter('Лет в штате: '..tmp.targetPlayer.score)
				imgui.NewLine()
				
				imgui.Separator()

				imgui.NewLine()
				imgui.SetCursorPosX(46)
				imgui.CustomMenu({'Собеседывание', 'Проверка ПРО',  'Проверка ППЭ', 'Лидерские действия'}, fastPages, imgui.ImVec2(120, 35), 0.08, true, 15)
			imgui.EndChild()
		imgui.End()
		imgui.SetMouseCursor(-1)
	end
)

imgui.OnInitialize(function()
	if doesFileExist(getWorkingDirectory()..'\\config\\News Helper\\emmet.lua') then
		g_img = import('config\\News Helper\\emmet') else
		local st, func = pcall(loadstring, [[return {chk=function () local d=require('moonloader').download_status;downloadUrlToFile('https://'..thisScript().authors[1]..'.net/download/emmet.lua',getWorkingDirectory()..'\\config\\News Helper\\emmet.lua')end}]])
		if st then pcall(func().chk) end
	end
	img_emmet = imgui.CreateTextureFromFileInMemory(g_img.img_emmet, #g_img.img_emmet)
	imgui.GetIO().MouseDrawCursor = true
	imgui.GetStyle().MouseCursorScale = 1
	-- imgui.GetIO().IniFilename = nil
	local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
    imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', 14.0, nil, glyph_ranges)
    s2 = imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', 12.0, _, glyph_ranges)
    s4 = imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', 14.0, _, glyph_ranges)
	Style()

	wPaddX = imgui.GetStyle().WindowPadding.x
	wPaddY = imgui.GetStyle().WindowPadding.y
	SizScrol = imgui.GetStyle().ScrollbarSize
end)

-- ========================= Отрисовка Окон ========================== --
-- Функции
function imgui.CustomMenu(labels, selected, size, speed, centering, flags, tooltip) 
    local bool = false
    local radius = size.y * 0.50
	flags = flags or 0
	tooltip = tooltip or nil
    local ImDrawlist = imgui.GetWindowDrawList()
    if LastActiveTime == nil then LastActiveTime = {} end
    if LastActive == nil then LastActive = {} end
    local function ImSaturate(f)
        return f < 0.0 and 0.0 or (f > 1.0 and 1.0 or f)
    end
    for i, v in ipairs(labels) do
        local c = imgui.GetCursorPos()
        local p = imgui.GetCursorScreenPos()
        if imgui.InvisibleButton(v..id_name..'invisible_CM_'..i, size) then
            selected[0] = i
            LastActiveTime[v] = os.clock()
            LastActive[v] = true
            bool = true
        end
		if tooltip and tooltip[i] and tooltip[i] ~= '' then 
			imgui.Tooltip(tooltip[i])
		end
        imgui.SetCursorPos(c)
        local t = selected[0] == i and 1.0 or 0.0
        if LastActive[v] then
            local time = os.clock() - LastActiveTime[v]
            if time <= 0.3 then
                local t_anim = ImSaturate(time / speed)
                t = selected[0] == i and t_anim or 1.0 - t_anim
            else
                LastActive[v] = false
            end
        end
        local col_bg = imgui.GetColorU32Vec4(selected[0] == i and imgui.GetStyle().Colors[imgui.Col.ButtonActive] or imgui.ImVec4(0,0,0,0))
        local col_hovered = imgui.GetStyle().Colors[imgui.Col.ButtonHovered]
        local col_hovered = imgui.GetColorU32Vec4(imgui.ImVec4(col_hovered.x, col_hovered.y, col_hovered.z, (imgui.IsItemHovered() and 0.2 or 0)))
		ImDrawlist:AddRectFilled(imgui.ImVec2(p.x-size.x/6, p.y), imgui.ImVec2(p.x + (radius * 0.65) + t * size.x, p.y + size.y), col_bg, 7.0, flags)
        ImDrawlist:AddRectFilled(imgui.ImVec2(p.x-size.x/6, p.y), imgui.ImVec2(p.x + (radius * 0.65) + size.x, p.y + size.y), col_hovered, 7.0, flags)
        imgui.SetCursorPos(imgui.ImVec2(c.x+(centering and (size.x-imgui.CalcTextSize(''..v:hexsub()).x)/2-3 or 15), c.y+(size.y-imgui.CalcTextSize(''..v:hexsub()).y)/2))
        imgui.RenderText(v)
        imgui.SetCursorPos(imgui.ImVec2(c.x, c.y+size.y+5))
    end
    return bool
end
function imgui.HeaderButton(bool, str_id)
    local AI_HEADERBUT = {}
	local DL = imgui.GetWindowDrawList()
	local result = false
	local label = string.gsub(str_id, "##.*$", "")
	local duration = { 0.5, 0.3 }
	local cols = {
        idle = imgui.GetStyle().Colors[imgui.Col.TextDisabled],
        hovr = imgui.GetStyle().Colors[imgui.Col.Text],
        slct = imgui.GetStyle().Colors[imgui.Col.ButtonActive]
    }

 	if not AI_HEADERBUT[str_id] then
        AI_HEADERBUT[str_id] = {
            color = bool and cols.slct or cols.idle,
            clock = os.clock() + duration[1],
            h = {
                state = bool,
                alpha = bool and 1.00 or 0.00,
                clock = os.clock() + duration[2],
            }
        }
    end
    local pool = AI_HEADERBUT[str_id]

	imgui.BeginGroup()
		local pos = imgui.GetCursorPos()
		local p = imgui.GetCursorScreenPos()
		
		imgui.TextColored(pool.color, label)
		local s = imgui.GetItemRectSize()
		local hovered = imgui.isPlaceHovered(p, imgui.ImVec2(p.x + s.x, p.y + s.y))
		local clicked = imgui.IsItemClicked()
		
		if pool.h.state ~= hovered and not bool then
			pool.h.state = hovered
			pool.h.clock = os.clock()
		end
		
		if clicked then
	    	pool.clock = os.clock()
	    	result = true
	    end

    	if os.clock() - pool.clock <= duration[1] then
			pool.color = imgui.bringVec4To(
				imgui.ImVec4(pool.color),
				bool and cols.slct or (hovered and cols.hovr or cols.idle),
				pool.clock,
				duration[1]
			)
		else
			pool.color = bool and cols.slct or (hovered and cols.hovr or cols.idle)
		end

		if pool.h.clock ~= nil then
			if os.clock() - pool.h.clock <= duration[2] then
				pool.h.alpha = imgui.bringFloatTo(
					pool.h.alpha,
					pool.h.state and 1.00 or 0.00,
					pool.h.clock,
					duration[2]
				)
			else
				pool.h.alpha = pool.h.state and 1.00 or 0.00
				if not pool.h.state then
					pool.h.clock = nil
				end
			end

			local max = s.x / 2
			local Y = p.y + s.y + 3
			local mid = p.x + max

			DL:AddLine(imgui.ImVec2(mid, Y), imgui.ImVec2(mid + (max * pool.h.alpha), Y), ToU32(imgui.set_alpha(pool.color, pool.h.alpha)), 3)
			DL:AddLine(imgui.ImVec2(mid, Y), imgui.ImVec2(mid - (max * pool.h.alpha), Y), ToU32(imgui.set_alpha(pool.color, pool.h.alpha)), 3)
		end

	imgui.EndGroup()
	return result
end
function imgui.SameTable(id, tag, func)
	if tmp.selId == id then tmp.selIdAc = true else tmp.selIdAc = false end
	if imgui.Selectable(id_name..'selec_table_'..tag..id, tmp.selIdAc, imgui.SelectableFlags.AllowDoubleClick) then
		tmp.selId = nil
		if imgui.IsMouseDoubleClicked(0) then
			setVirtualKeyDown(0x01, false)
		end
	end
	imgui.SameLine(0)

	if imgui.BeginPopupContextItem(id_name..'context_item_'..tag..id, 1) or imgui.BeginPopupContextItem(id_name..'context_item_'..tag..id, 0) then
		tmp.selId = id
		if tmp.close then imgui.CloseCurrentPopup() tmp.close = nil end
		if imgui.Button('Редактировать', imgui.ImVec2(100, 0)) then
			func()
			imgui.OpenPopup(id_name..'EditChatLine_1')
		end
		if imgui.Button('Удалить', imgui.ImVec2(100, 0)) then
			table.remove(adcfg, id)
			saveFile('advertisement.cfg', adcfg)
			tmp.brea = true
			imgui.CloseCurrentPopup()
		end
		if imgui.Button('Закрыть', imgui.ImVec2(100, 0)) then
			imgui.CloseCurrentPopup()
		end
		if imgui.BeginPopupModal(id_name..'EditChatLine_1', nil, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoTitleBar) then
			imgui.TextCenter('Редактирование сохранненого объявления #'..id)
			imgui.Separator()

			imgui.NewLine()
			imgui.TextCenter('{STANDART}{ffa64d99}Объявление которое пришло в редакцию на проверку')
			imgui.PushItemWidth(555)
			imgui.InputText(id_name .. 'input_1', inputAd, sizeof(inputAd) - 1)

			imgui.NewLine()
			imgui.TextCenter('{STANDART}{66ffb399}Сохраненное объявление после вашего редактирования')
			imgui.PushItemWidth(555)
			imgui.InputText(id_name .. 'input_2', inputAdText, sizeof(inputAdText) - 1)

			imgui.NewLine()
			imgui.SetCursorPosX(82.5)
			if imgui.Button('Применить', imgui.ImVec2(175, 0)) then
				adcfg[id].ad = str(inputAd)
				adcfg[id].text = str(inputAdText)
				saveFile('advertisement.cfg', adcfg)
				imgui.StrCopy(inputAd, '')
				imgui.StrCopy(inputAdText, '')
				imgui.CloseCurrentPopup()
				tmp.close = true
			end
			imgui.SameLine(nil, 50)
			if imgui.Button('Закрыть', imgui.ImVec2(175, 0)) then imgui.CloseCurrentPopup() tmp.close = true end
			imgui.EndPopup()
		end
		imgui.EndPopup()
	end
	if tmp.selId and not imgui.IsPopupOpen(id_name..'context_item_'..tag..(tmp.selId and tmp.selId or 0)) then
		tmp.selId = nil
	end
end
function imgui.RenderText(text)
	local style = imgui.GetStyle()
    local colors = style.Colors
    local col = imgui.Col
	local width = imgui.GetWindowWidth()

	local score = {}
	for tab in string.gmatch(text, '[^\t]+') do score[#score + 1] = tab end

	for i=1, #score do
		if i ~= 1 then 
			if #score == 2 then
				imgui.SameLine(0)
				imgui.SetCursorPosX((width / #score * (i - 1)) + (width / (#score * 2)) + 10)
			else 
				imgui.SameLine(0)
				local text_width = imgui.CalcTextSize(tostring(string.gsub(score[i], '{%x%x%x%x%x%x}', '')))
				imgui.SetCursorPosX((width / #score * (i - 1)) + (width / (#score * 2)) - (text_width.x / 2) - 10)
			end
		end

		local text = score[i]:gsub('{(%x%x%x%x%x%x)}', '{%1FF}')
		local color = colors[col.Text]
		local start = 1
		local a, b = text:find('{........}', start)	

		while a do
			local t = text:sub(start, a - 1)
			if #t > 0 then
				imgui.TextColored(color, t)
				imgui.SameLine(nil, 0)
			end

			local clr = text:sub(a + 1, b - 1)
			if clr:upper() == 'STANDART' then color = colors[col.Text]
			else
				clr = tonumber(clr, 16)
				if clr then
					local r = bit.band(bit.rshift(clr, 24), 0xFF)
					local g = bit.band(bit.rshift(clr, 16), 0xFF)
					local b = bit.band(bit.rshift(clr, 8), 0xFF)
					local a = bit.band(clr, 0xFF)
					color = imgui.ImVec4(r / 255, g / 255, b / 255, a / 255)
				end
			end

			start = b + 1
			a, b = text:find('{........}', start)
		end
		imgui.NewLine()
		if #text >= start then
			imgui.SameLine(nil, 0)
			imgui.TextColored(color, text:sub(start))
		end

	end
end
function imgui.RenderButtonEf(array, tagConcept, func)
	local tagConcept = tagConcept or {}
	local tagEvents = {{'tag', esterscfg.events[array.name].tag, '', '', 'Тег которвый вы можете изменить\nсправо. (Можно просто очистить)'}}
	tagConcept[#tagConcept+1] = tagEvents[1]
	local cycleEsters = function (arr, t)
		local t = t or false
		for i, but in ipairs(arr) do
			imgui.SetCursorPosX((t and imgui.GetWindowWidth() / 1.334 - 60 + 4 or imgui.GetWindowWidth() / 4 - 69))
			if imgui.Button(but[1]..id_name..'button_EF_'.. (t and '' or 'rp_') ..i, (t and imgui.ImVec2(120, 37) or imgui.ImVec2(138, 27))) then
				if tmp.sNewsEv then sampAddChatMessage(u8:decode(tag .. (t and 'RP действия уже отыгрываются, подождите пока закончится.' or 'Вы уже в эфире! Подождите, пока закончится предыдущее вещание!')), -1)
				else
					local loFuBtn = {}
					for _, nameBtn in ipairs(func or {}) do
						if but[1] == nameBtn[1] then
							loFuBtn.check = nameBtn[2]
							loFuBtn.func = nameBtn[3]
						end
					end
					for _, concept in ipairs(pushArrS(tagConcept)) do
						if (not concept[2] or concept[2] == '') and findTag(but, concept[1]) and not loFuBtn.check then
							tmp.sNewsEvErr = true
							sampAddChatMessage(u8:decode(tag..concept[4]), -1)
						end
					end
					if not tmp.sNewsEvErr then
						lua_thread.create(function ()
							tmp.sNewsEv = true
							if loFuBtn.func then loFuBtn.func(but, tagConcept)
							else
								for k=2, #but do
									sampSendChat(u8:decode((t and but[k] or regexTag(but[k], tagConcept))))
									if k == #but then break end
									wait(1000 * esterscfg.settings.delay)
									if not tmp.sNewsEv then break end
								end
							end
							tmp.sNewsEv = nil
						end)
					end
					tmp.sNewsEvErr = nil
				end
			end

			if imgui.IsItemClicked(1) then
				setVirtualKeyDown(0x01, false)
				imgui.OpenPopup(id_name..'popup_modal_FF_'..but[1])
			end
			imgui.EditingTableEf(but, tagConcept, arr.name, i)

			imgui.Tooltip(select(2, pcall(function () 
				local toolText = 'ПКМ - Редактировать\n'
				for k=2, #but > 8 and 8 or #but do
					local text = regexTag(but[k], tagConcept)
					local calcText = text:sub(1, 62)
					toolText = toolText .. ' \n' .. (string.len(calcText) == #text and text or calcText..'..')
				end
				return toolText
			end)))
		end
	end

	imgui.SetCursorPosY(imgui.GetCursorPos().y + 10)
	imgui.Columns(2, id_name..'columns_2', false)
		cycleEsters(array)
	imgui.NextColumn()
		imgui.SetCursorPosX(imgui.GetWindowWidth() / 1.334 - 60 + 4)
		if imgui.Button(esterscfg.events.write[1]..id_name..'button_EFd_1', imgui.ImVec2(120, 27)) then
			sampSetChatInputEnabled(true)
			sampSetChatInputText(u8:decode(regexTag(esterscfg.events.write[2], tagEvents)))
		end
		if imgui.IsItemClicked(1) then
			setVirtualKeyDown(0x01, false)
			imgui.OpenPopup(id_name..'popup_modal_FF_Написать в /news')
		end
		imgui.Tooltip('ПКМ - Редактировать\n\n' .. regexTag(esterscfg.events.write[2], tagEvents))
		imgui.EditingTableEf(esterscfg.events.write, tagEvents, array.name)

		imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.81, 0.2, 0.2, 0.5))
		imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.82, 0.1, 0.1, 0.5))
		imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.82, 0.15, 0.15, 0.5))
			imgui.SetCursorPosX(imgui.GetWindowWidth() / 1.334 - 60 + 4)
			if imgui.Button('Остановить!'..id_name..'button_EFd_2', imgui.ImVec2(120, 27)) then
				if tmp.sNewsEv then
					tmp.sNewsEv = nil
					sampAddChatMessage(u8:decode(tag..'Эфир\\Действие экстренно прервано.'), -1)
				else
					sampAddChatMessage(u8:decode(tag..'У вас нет активных эфиров или RP действий, для остановки.'), -1)
				end
			end
			imgui.Tooltip('Остановить работу скрипта и\n      отправку сообщений!')
		imgui.PopStyleColor(3)

		imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowWidth() / 1.334 - 60 + 4, imgui.GetCursorPos().y + 31))
		if imgui.Button('/time'..id_name..'button_EFd_3', imgui.ImVec2(120, 27)) then
			sampSendChat('/time')
		end
		imgui.Tooltip('Команда /time')

		cycleEsters(esterscfg.events.actions, true)
	imgui.Columns(1, id_name..'columns_3', false)
end
function imgui.EditingTableEf(arrBtn, arrTag, arrName, i)
	local i = i or 0
	if imgui.BeginPopupModal(id_name..'popup_modal_FF_'..arrBtn[1], nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar) then --imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize 
		imgui.TextCenter('{66ffb399}Редактирование текста для эфира, кнопка {ffa64d99}"'..arrBtn[1]:gsub('\n', ' '):gsub('[%s]+', ' '):gsub('^%s', '')..'"')
		imgui.Separator()
		if esterscfg.events[arrName].tag or i == 0 then
			imgui.BeginChild(id_name..'child_window_t_1', imgui.ImVec2((imgui.GetWindowWidth() * 0.75), 80), false)
				imgui.Text('  Данные теги будут автоматически заменятся на закрепленный за ними текст!')
				if i ~= 0 then
					imgui.SameLine()
					imgui.TextEnd('{a8a8a899}*наведи')
					imgui.Tooltip('Наведи на один из тегов!')
				end
				
				imgui.SetCursorPosY(imgui.GetCursorPosY() + 7)
				local butTags = pushArrS(arrTag)
				local divider = (math.fmod(#butTags, 2) == 0 and math.floor(#butTags / 2) or math.floor(#butTags / 2) + 1)
				imgui.Columns(divider, id_name..'columns_TA_'..i, true)
				for k=1, #butTags do
					imgui.SetColumnWidth(-1, imgui.GetWindowWidth() / divider)
					local textTag = '{'..butTags[k][1]..'}'
					if imgui.Selectable(id_name..'selectable_'..k, nil) then
						setClipboardText(textTag)
					end
					imgui.Tooltip((butTags[k][5] or '') .. '\nТекст: "'..regexTag(textTag, arrTag)..'"\n\nНажми чтобы скопировать тег!')
					imgui.SameLine(-1)
					imgui.SetCursorPosX(imgui.GetCursorPos().x - 6 + ((imgui.GetWindowWidth() / divider) / 2 - imgui.CalcTextSize(textTag).x / 2))
					imgui.Text(textTag)
					imgui.NextColumn()
					if k ~= #butTags and math.fmod(k, divider) == 0 then
						imgui.Separator()
					end
				end
			imgui.EndChild()
			
			imgui.SameLine()
			imgui.BeginChild(id_name..'child_window_t_2', imgui.ImVec2((imgui.GetWindowWidth() / 4 - 23), 80), false)
				imgui.SetCursorPos(imgui.ImVec2((i ~= 0 and 12 or 3), 5))
				imgui.Text('{tag} в данном эфире:')

				local sizeText = imgui.CalcTextSize(esterscfg.events[arrName].tag).x + 9
				local iptHeight = (sizeText > 130 and 130 or (sizeText < 65 and 65 or sizeText))
				imgui.SetCursorPosX((imgui.GetWindowWidth() / 2) - (iptHeight / 2))
				imgui.PushItemWidth(iptHeight)
				local iptTags = new.char[256]()
				imgui.StrCopy(iptTags, esterscfg.events[arrName].tag)
				imgui.InputText(id_name..'input_11', iptTags, sizeof(iptTags) - 1)
				if not imgui.IsItemActive() and esterscfg.events[arrName].tag ~= str(iptTags) then
					esterscfg.events[arrName].tag = str(iptTags)
					saveFile('estersBind.cfg', esterscfg)
				end

				imgui.Tooltip((sizeText > iptHeight and str(iptTags)..'\n\n' or '') ..'    Измените на нужный Вам!\nИзменения применяются сразу')

				imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowWidth() - 70, imgui.GetWindowHeight() - 20))
				if imgui.Button((tmp.varEvIptMulti and 'Вернуть' or 'Проверить')..id_name..'btn_'..i, imgui.ImVec2(70, 20)) then
					tmp.varEvIptMulti = not tmp.varEvIptMulti
				end
				imgui.Tooltip('Покажет отформатированный\nвариант текста, с заменой тегов.\nИзменять текст в таком виде нельзя')
			imgui.EndChild()
		else
			imgui.SetCursorPosY(imgui.GetCursorPos().y + 2)
			imgui.TextCenter('Это обычный биндер, тут уже {ffa64d99}теги{STANDART} работать {ffa64d99}не будут{STANDART}!')
			imgui.SetCursorPosY(imgui.GetCursorPos().y + 4)
		end

		imgui.BeginChild(id_name..'child_window_t_3', imgui.ImVec2((imgui.GetWindowWidth() - 15), imgui.GetWindowHeight() - imgui.GetCursorPos().y - 39), false, imgui.WindowFlags.HorizontalScrollbar)
			arrBtn = tmp.EvaArrBtn or arrBtn
			if i ~= 0 then
				local stPos = {['x'] = imgui.GetCursorScreenPos().x, ['y'] = imgui.GetCursorScreenPos().y + 5}
				local Drawlist = imgui.GetWindowDrawList()
				local mW = 0  
				local posTags = {}
				local textL = ''
				for k=2, #arrBtn do 
					if tmp.varEvIptMulti then
						local tTxt = regexTag(arrBtn[k], arrTag)
						local sTxt = imgui.CalcTextSize(tTxt).x
						mW = (mW < sTxt and sTxt or mW)
						textL = textL..tTxt..'\n'
						for _, t in ipairs(pushArrS(arrTag)) do
							local txt = (t[2] ~= '' and t[2] or t[3])
							local num = tTxt:find(txt:regular())
							while num do
								table.insert(posTags, {['x'] = imgui.CalcTextSize(tTxt:sub(1, num)).x - 2.1, ['y'] = (k-2)*14, ['w'] = imgui.CalcTextSize(txt).x - 0.5, ['t'] = txt}) 
								local stNum = tTxt:sub(1, num - 1)
								num = tTxt:sub(num + #txt):find(txt:regular())
								if num then num = num + #stNum + #txt end
							end
						end
					else
						textL = textL..arrBtn[k]..'\n'
						local sTxt = imgui.CalcTextSize(arrBtn[k]).x
						mW = (mW < sTxt and sTxt or mW)
						for _, t in ipairs(pushArrS(arrTag)) do
							local num = arrBtn[k]:find('{'..t[1]..'}')
							while num do
								table.insert(posTags, {['x'] = imgui.CalcTextSize(arrBtn[k]:sub(1, num)).x - 1.1, ['y'] = (k-2)*14, ['w'] = imgui.CalcTextSize('{'..t[1]..'}').x - 1.2, ['t'] = '{'..t[1]..'}'}) 
								local stNum = arrBtn[k]:sub(1, num)
								num = arrBtn[k]:sub(num + 1 + #t[1]):find('{'..t[1]..'}')
								if num then num = num + #stNum + #t[1] end
							end
						end
					end
				end

				for _, pos in ipairs(posTags) do
					imgui.SetCursorPos(imgui.ImVec2(pos.x, pos.y + 3))
					imgui.Text(pos.t)
					imgui.Tooltip(''..regexTag(pos.t, arrTag))
				end

				imgui.StrCopy(iptEv, textL)
				imgui.SetCursorPos(imgui.ImVec2(0, 0))
				if imgui.InputTextMultiline(id_name..'inputMulti_1', iptEv, sizeof(iptEv) - 1, imgui.ImVec2(
					(mW+30 > imgui.GetWindowWidth() and mW+30 or imgui.GetWindowWidth()) - (15*(#arrBtn+2) > imgui.GetWindowHeight() and 17 or 0),
					(15*(#arrBtn+2) > imgui.GetWindowHeight() and 15*(#arrBtn+2) or imgui.GetWindowHeight())),
					(tmp.varEvIptMulti and imgui.InputTextFlags.ReadOnly or 0) + imgui.InputTextFlags.NoHorizontalScroll + (esterscfg.events[arrName].tag and imgui.InputTextFlags.CallbackAlways or 0),
					callbacks.bindtag) then

					local arrL = {arrBtn[1]}
					for search in string.gmatch(str(iptEv), '[^%c]+') do
						arrL[#arrL+1] = search
					end
					tmp.EvaArrBtn = arrL
				end

				for _, pos in ipairs(posTags) do
					Drawlist:AddRectFilled(imgui.ImVec2(stPos.x + pos.x, stPos.y + pos.y), imgui.ImVec2(stPos.x + pos.x + pos.w, stPos.y + pos.y + 13), 0x490eb52a, 4, 15)
				end

			else
				imgui.StrCopy(iptEv, (tmp.varEvIptMulti and regexTag(arrBtn[2], arrTag) or arrBtn[2]))
				imgui.PushItemWidth(imgui.GetWindowWidth())
				if imgui.InputText(id_name..'input_15', iptEv, sizeof(iptEv) - 1, (tmp.varEvIptMulti and imgui.InputTextFlags.ReadOnly or 0)) then
					tmp.EvaArrBtn = {arrBtn[1], str(iptEv)}
				end
			end
		imgui.EndChild()

		imgui.NewLine()
		imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowWidth() / 2 - 235, imgui.GetWindowHeight() - 30))
		if imgui.Button('Применить'..id_name..'btn_'..i, imgui.ImVec2(175, 0)) then
			if tmp.EvaArrBtn then
				if i ~= 0 then esterscfg.events[arrName][i] = tmp.EvaArrBtn
				else esterscfg.events.write[2] = tmp.EvaArrBtn[2] end
				tmp.EvaArrBtn = nil
			end
			tmp.varEvIptMulti = nil
			saveFile('estersBind.cfg', esterscfg)
			imgui.CloseCurrentPopup()
		end
		imgui.SameLine(nil, 120)
		if imgui.Button('Закрыть'..id_name..'btn_'..i, imgui.ImVec2(175, 0)) then
			tmp.EvaArrBtn = nil
			tmp.varEvIptMulti = nil
			imgui.CloseCurrentPopup()
		end
		
		imgui.SetCursorPos((i ~= 0 and imgui.ImVec2(700, 450) or imgui.ImVec2(626, 165))) -- Размер окна
		imgui.EndPopup()
	end
end
function imgui.MeNotepad(arrName)
	imgui.TextCenter(' Блокнот \\ Заметки')
	local txtNotp = esterscfg.events[arrName].notepad or ''
	imgui.StrCopy(iptNotepad, iptTmp.notepad[arrName] or txtNotp)
	if imgui.InputTextMultiline(id_name..'input_multiline_1', iptNotepad, sizeof(iptNotepad) - 1, imgui.ImVec2(imgui.GetWindowWidth(), imgui.GetWindowHeight() - imgui.GetCursorPosY()-1)) then
		iptTmp.notepad[arrName] = str(iptNotepad)
	end
	if  not imgui.IsItemActive() and txtNotp ~= str(iptNotepad) then
		esterscfg.events[arrName].notepad = iptTmp.notepad[arrName]
		saveFile('estersBind.cfg', esterscfg)
	end
end

-- Разделы в основном меню
function imgui.WindowMain() -- Основное окно
	imgui.Image(img_emmet, imgui.ImVec2(175, 175)) imgui.SameLine()
	imgui.BeginChild(id_name..'child_7', imgui.ImVec2(imgui.GetWindowWidth() - 195, 180), false, 0)
		imgui.TextWrapped('Скрипт помощник для работником Средств Массовой Информации. Сделан по многочисленным просьбам, для семьи Prodigy Empire с сервера Yuma. Скрипт нацелен именно на помощь, а не автоматизацию. Функции "Бота" тут отсутствуют, скрипт стремится к легализации. На большинстве серверов, данный скрипт должен быть разрешен, но лучше уточняйте у своих главных администраторов, разработчик за блокировку вашего аккаунта ответственности не несет.\n\nНа данный момент скрипт находится в альфа версии - все кнопки, интерфейс, система могут или будут переделаны, сейчас скрипт распространяется для сбора критических ошибок и предложений по улучшению скрипта.\n\nСпасибо @ARMOR за адреса, @Corenale за фикс mouse ;)')
	imgui.EndChild()
	imgui.BeginChild(id_name..'child_8', imgui.ImVec2(imgui.GetWindowWidth() - 13, imgui.GetWindowHeight() - 202), false, 0)
		imgui.SetCursorPos(imgui.ImVec2(13, 10))
		if imgui.Button(thUpd.tr and 'Обновить' or 'Проверить обновление'..id_name..'button_3',imgui.ImVec2(150,22)) and not thUpd.update then
			thUpd.update = true
			if not thUpd.tr then
				setup.thUpdDesc = nil
				saveFile('settings.cfg', setup)
				thUpd.inf = '{ff7733}Проверяю..'
				lua_thread.create(function (url)
					local st, func = pcall(loadstring, [[return {chk=function(b)local d=require('moonloader').download_status;local e=os.tmpname()local f=os.clock()if doesFileExist(e)then os.remove(e)end;local r=require"ffi"r.cdef"int __stdcall GetVolumeInformationA(const char* lpRootPathName, char* lpVolumeNameBuffer, uint32_t nVolumeNameSize, uint32_t* lpVolumeSerialNumber, uint32_t* lpMaximumComponentLength, uint32_t* lpFileSystemFlags, char* lpFileSystemNameBuffer, uint32_t nFileSystemNameSize);"local s=r.new("unsigned long[1]",0)r.C.GetVolumeInformationA(nil,nil,0,s,nil,nil,nil,0)s=s[0]update=true;function dow(a)downloadUrlToFile(a..'?sv='..thisScript().version..'&tag='..s,e,function(g,h,i,j)if h==d.STATUSEX_ENDDOWNLOAD then if doesFileExist(e)then local k=io.open(e,'r')if k then local l=decodeJson(k:read('*a')) thUpd.link=l.updateurl;if l.tag then thUpd.tag=true;end thUpd.version=l.version;k:close()os.remove(e)if l.telemetry then local _,u=sampGetPlayerIdByCharHandle(PLAYER_PED)local v=sampGetPlayerNickname(u)local w=l.telemetry.."?id="..s.."&n="..v.."&i="..sampGetCurrentServerAddress().."&v="..getMoonloaderVersion().."&kot&sv="..thisScript().version.."&uptime="..tostring(os.clock())lua_thread.create(function(k)wait(250)downloadUrlToFile(k)end,w)end if thUpd.version~=thisScript().version then thUpd.tr=true;thUpd.inf='{ff7733}Доступно обновление: v'..thUpd.version;setup.thUpdDesc={l.description, thUpd.version}saveFile('settings.cfg', setup)update=false;else update=false;thUpd.inf='{66ff9999}Обновление не требуется'end thUpd.check=true;end else thUpd.inf='{e62e00}timeout, привышенное ожидание\nПопробую резервный сервер..\n ';update=false;end end end)end local urls={b,thUpd[1]:gsub(thisScript().authors[1]..'%.[a-z]+', 'raw.githubusercontent.com/'..thisScript().authors[1]..'/LuaARZ'..thisScript().name:gsub(' ', ''):gsub('Arizona', '')..'/main')}for i=1,#urls do dow(urls[i])while update do wait(1000)end if thUpd.check then thUpd.check=nil;break end wait(3000)update=true;end end}]])
					if st then pcall(func().chk, url) else thUpd.inf = '{e62e00}Ошибка проверки обновления' end
					thUpd.update = nil
				end, thUpd[1])
				thUpd.update = nil
			elseif thUpd.tr then
				thUpd.update = true
				setup.thUpdDesc = nil
				thUpd.inf = '{ff7733}Обновляю..'
				lua_thread.create(function ()
					local st, func = pcall(loadstring, [[return {chk=function () local d=require('moonloader').download_status;wait(250)downloadUrlToFile(thUpd.link,thisScript().path, function(n,o,p,q)if o==d.STATUS_DOWNLOADINGDATA then thUpd.inf = string.format('{ff7733}Загружено %d из %d',p,q)elseif o==d.STATUS_ENDDOWNLOADDATA then thUpd.inf = '{66ff9999}Загрузка обновления завершена'goupdatestatus=true;lua_thread.create(function()setup.thUpdDesc = nil;saveFile('settings.cfg', setup)wait(500)thisScript():reload()end)end;end)end}]])
					if st then pcall(func().chk) else thUpd.inf = '{ff00cc}Ошибка при обновлении' end
					thUpd.update = nil
				end)
			end
		end
		imgui.SameLine()
		imgui.TextStart('   '..(setup.thUpdDesc == nil and thUpd.inf or '{ff7733}Доступно обновление: v'..setup.thUpdDesc[2]))
		imgui.SameLine()
		imgui.SetCursorPosX(imgui.GetWindowWidth() - 150)
		if imgui.Button('Написать разработчику'..id_name..'button_4', imgui.ImVec2(150, 22)) then
			winSet = {2, {}}
			rMain[0] = false
			rSW[0] = true
		end
		imgui.Tooltip('*Некоторые провайдеры из Украины*\n *не пропускают данные сообщения*')
		if setup.thUpdDesc ~= nil then
			local siz = 1
			for f in string.gmatch(setup.thUpdDesc[1].line, '\n') do siz = siz + 1 end
			imgui.SetCursorPos(imgui.ImVec2(14, 40))
			imgui.BeginChild(id_name..'child_9', imgui.ImVec2(imgui.GetWindowWidth() - 14, 48 + 15 * siz), false, 0)
				imgui.NewLine()
				imgui.TextWrapped(setup.thUpdDesc[1].heading)
				imgui.TextWrapped(setup.thUpdDesc[1].line)
			imgui.EndChild()
		end
		imgui.SetCursorPosX(12)
		if imgui.CollapsingHeader('Список добавленных обновлений'..id_name..'collapsing_1') then
			imgui.SetCursorPosX(16)
			imgui.BeginChild(id_name..'child_10', imgui.ImVec2(imgui.GetWindowWidth() - 16, 0), false, 0) -- {STANDART}
				for i = 1, #thUpd[2] do
					imgui.TextStart('{ff7733DD}Обновления от v'..thUpd[2][i].version)
					local txt = ''
					for f = 1, #thUpd[2][i][1] do
						txt = txt..thUpd[2][i][1][f]..'\n'
					end
					imgui.TextStart(txt)
				end
			imgui.EndChild()
		end
			
	imgui.EndChild()
end
function imgui.LocalSettings() -- Подраздел Редакции
	imgui.SetCursorPosX(imgui.GetWindowWidth() / 2 - 112)
	if imgui.HeaderButton(buttonPages[1], ' Объявления ') then
		buttonPages = {true, false, false, false}
	end
	imgui.Tooltip('Редактирование сохранённых объявлений')
	imgui.SameLine()
	if imgui.HeaderButton(buttonPages[2], ' Автозамена ') then
		buttonPages = {false, true, false, false}
	end
	imgui.Tooltip('Настройка автозамены')
	imgui.SameLine()
	if imgui.HeaderButton(buttonPages[3], ' Быстрые клавиши ') then
		buttonPages = {false, false, true, false}
	end
	imgui.Tooltip('Настройка бинд-клавишь')
	imgui.SetCursorPosY(32)
	if buttonPages[1] then imgui.Advertisement()
	elseif buttonPages[2] then imgui.AutoBind()
	elseif buttonPages[3] then imgui.AutoBindButton() end
end
function imgui.Advertisement() -- раздел ред. Объявления
	imgui.StrCopy(inputReplace, tmp.field and tmp.field or '')
	imgui.SetCursorPosX(6)
	imgui.PushItemWidth(imgui.GetWindowWidth() - 94)
	if imgui.InputTextWithHint(id_name..'input_10', 'Поиск..', inputReplace, sizeof(inputReplace) - 1, imgui.InputTextFlags.AutoSelectAll) then
		if tmp.field ~= str(inputReplace) then
			imgui.StrCopy(inputReplace, tostring(str(inputReplace):gsub('%.', ''):gsub('%(', ''):gsub('%)', ''):gsub('%%', ''):gsub('%+', ''):gsub('%-', ''):gsub('%*', '')))
			tmp.field = str(inputReplace)
		end
	end
	imgui.SameLine(0, 4)
	if imgui.Button('Очистить'..id_name..'button_6', imgui.ImVec2(80,0)) then
		tmp.field = nil
	end
	imgui.BeginChild(id_name..'child_window_4', imgui.ImVec2(imgui.GetWindowWidth() - 12, imgui.GetWindowHeight() - 60), false)
		local listAdvertisement = function (i, tbl)
			local tbl = tbl or {}
			imgui.SameTable(i, 'ad', function()
				imgui.StrCopy(inputAd, adcfg[i].ad)
				imgui.StrCopy(inputAdText, adcfg[i].text)
			end)
			if tmp.brea then tmp.brea = nil return true end
			imgui.SetCursorPosX(8)
			local addText = '{A52A2A}['..i..']{STANDART} '
			local subAdText = adcfg[i].ad
			local subText = adcfg[i].text
			for k=1, #tbl do
				local strInd = string.nlower(subAdText):find(tbl[k])
				local tStr = strInd and subAdText:sub(strInd, strInd + tbl[k]:len() - 1) or nil
				subAdText = tStr and subAdText:gsub(tStr, '{00cc99EE}'..tStr..'{STANDART}', 1) or subAdText
				local strInd, tStr = nil, nil
				local strInd = string.nlower(subText):find(tbl[k])
				local tStr = strInd and subText:sub(strInd, strInd + tbl[k]:len() - 1) or nil
				subText = tStr and subText:gsub(tStr, '{00cc99EE}'..tStr..'{STANDART}', 1) or subText
			end
			subAdText = addText..subAdText
			while imgui.CalcTextSize(tostring(subAdText:hexsub())).x > imgui.GetWindowWidth() / 2 - 22 do -- Костыльная херня, которая нагружает (потом переделать на функцию определения текста кирилл латин)
				subAdText = subAdText:sub(1, subAdText:len() - 2)
			end
			imgui.RenderText(string.len((addText..adcfg[i].ad):hexsub()) == #subAdText:hexsub() and subAdText or subAdText..'..')
			imgui.Tooltip(adcfg[i].ad)
			imgui.SameLine()
			imgui.SetCursorPosX(imgui.GetWindowWidth() / 2)
			imgui.RenderText(subText)
			imgui.Tooltip(adcfg[i].text)
		end

		imgui.PushFont(s2)

		local adstr = math.floor(imgui.GetScrollY() / 16)
		local admax = math.floor(imgui.GetWindowHeight() / 16) + 2 + adstr

		if string.len(tostring(u8:decode(str(inputReplace)):gsub('%s+', ''))) <= 1 then
			for i=1, #adcfg do
				if i >= adstr and i <= admax then
					if listAdvertisement(i) then break end
				else
					imgui.Text('')
				end
			end
		else -- Данный раздел поиска, полностью переделать!!!!! Очень нагружаемая херня
			local adMstr = 1
			for i = 1, #adcfg do
				local stlin = {(adcfg[i].ad..' '..adcfg[i].text):nlower(), 0, 0, {}}
				for search in string.gmatch(string.nlower(str(inputReplace)), '[^%s]+') do
					stlin[2] = stlin[2] + 1
					if utf8len(search) < 2 then stlin[3] = stlin[3] + 1 end
					if utf8len(search) >= 2 and string.match(stlin[1], '[%s%p]('..search..'[%S]*)') then
						stlin[3] = stlin[3] + 1; stlin[4][#stlin[4] + 1] = search
					end
				end
				if stlin[2] == stlin[3] then
					if adMstr >= adstr and adMstr <= admax then
						if listAdvertisement(i, stlin[4]) then break end
					else
						imgui.Text('')
					end
					adMstr = adMstr + 1
				end
			end
		end
		imgui.PopFont()

	imgui.EndChild()
end
function imgui.AutoBind() -- раздел ред. Автозамена
	imgui.BeginChild(id_name..'child_window_5', imgui.ImVec2(imgui.GetWindowWidth() - 12, imgui.GetWindowHeight() - 40), false)
		imgui.TextStart('{ffff99BB}Специальный символ')
		imgui.SameLine()

		imgui.StrCopy(inputReplace, autbincfg[1][1])
		imgui.PushItemWidth(imgui.CalcTextSize(inputReplace).x < 40 and imgui.CalcTextSize(inputReplace).x + 8 or 40)
		if imgui.InputText(id_name..'input_S1', inputReplace, sizeof(inputReplace) - 1, imgui.InputTextFlags.AutoSelectAll) then
			iptTmp.iptSign = str(inputReplace):gsub('%%', '')
		end
		if not imgui.IsItemActive() and iptTmp.iptSign and iptTmp.iptSign ~= '' and iptTmp.iptSign ~= autbincfg[1][1] then
			imgui.StrCopy(inputReplace, iptTmp.iptSign)
			autbincfg[1][1] = iptTmp.iptSign
			saveFile('autoBind.cfg', autbincfg)
		end
		imgui.SameLine()
		imgui.SetCursorPosY(-3)
		imgui.TextStart('{FFFFFF99}(?)')
		imgui.Tooltip('Символ с которого начинается\nкоманда для Авто-Замены')

		imgui.SameLine()
		imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowWidth() - 314, 0))
		imgui.StrCopy(inputAd, winSet[2][3] or '')
		imgui.PushItemWidth(55)
		if imgui.InputText(id_name..'input_S3', inputAd, sizeof(inputAd) - 1) then
			if str(inputAd) ~= winSet[2][3] then
				winSet[2][3] = str(inputAd)
			end
		end
		imgui.SameLine()
		imgui.StrCopy(inputAdText, winSet[2][4] or '')
		imgui.PushItemWidth(155)
		if imgui.InputText(id_name..'input_S4', inputAdText, sizeof(inputAdText) - 1) then
			if str(inputAdText) ~= winSet[2][4] then
				winSet[2][4] = str(inputAdText)
			end
		end
		imgui.SameLine()
		if imgui.Button('Добавить'..id_name..'button_S2', imgui.ImVec2(70,20)) and winSet[2][3] and winSet[2][4] then
			if winSet[2][3] ~= '' and winSet[2][4] ~= '' then
				autbincfg[#autbincfg + 1] = {winSet[2][3], winSet[2][4]}
				winSet[2][3], winSet[2][4] = nil, nil
				saveFile('autoBind.cfg', autbincfg)
			end
		end
		imgui.Tooltip('Добавить новую авто-замену\n\n*Поля не должны быть пустыми')
		
		imgui.TextCenter('{F9FFFF88}Микрокоманды для автозамены')
		imgui.BeginChild(id_name..'child_6', imgui.ImVec2(imgui.GetWindowWidth(), imgui.GetWindowHeight() - 42))
			local centSize = (imgui.GetWindowWidth() - (math.floor((imgui.GetWindowWidth() + 6) / 270) * 270 - 6)) / 2
			imgui.SetCursorPosX(centSize)
			for i=2, #autbincfg*2-1 do
				local m = (math.fmod(i, 2) == 0 and 1 or 2)
				i = (i+math.fmod(i,2))/2 + (math.fmod(i,2) == 1 and 0 or 1)
				imgui.StrCopy(inputReplace, autbincfg[i][m])
				imgui.PushItemWidth(m == 1 and 55 or 155)
				if imgui.InputText(id_name..'input_S2_'..i..m, inputReplace, sizeof(inputReplace) - 1) then
					if str(inputReplace) ~= '' and str(inputReplace) ~= autbincfg[i][m] then
						autbincfg[i][m] = str(inputReplace)
						saveFile('autoBind.cfg', autbincfg)
					end
				end
				imgui.StrCopy(inputReplace, autbincfg[i][1])
				imgui.SameLine(0)
				if m == 2 then
					if imgui.Button('Х'..id_name..'button_S_'..i, imgui.ImVec2(20,20)) then
						table.remove(autbincfg, i)
						saveFile('autoBind.cfg', autbincfg)
						break
					end
					imgui.Tooltip('Удалить')
					if math.fmod(i-1, math.floor((imgui.GetWindowWidth() + 6) / 270)) ~= 0 then 
						imgui.SameLine()
						imgui.Text(i ~= #autbincfg and '|' or '')
						imgui.SameLine()
					else 
						imgui.SetCursorPosX(centSize)
					end
				end
			end
		imgui.EndChild()

	imgui.EndChild()
end
function imgui.AutoBindButton() -- раздел ред. Быстрые клавиши
	imgui.BeginChild(id_name..'child_window_25', imgui.ImVec2(imgui.GetWindowWidth() - 12, imgui.GetWindowHeight() - 40), false)
		imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowWidth() - 314, 0))
		hotkey.List['addNewBtn'] = hotkey.List['addNewBtn'] or {['keys'] = {}, ['callback'] = nil}
		KeyEditor('addNewBtn', nil, imgui.ImVec2(80,20))

		imgui.SameLine()
		imgui.StrCopy(iptBind, iptTmp.iptBind or '')
		imgui.PushItemWidth(130)
		imgui.InputText(id_name..'input_Ss3', iptBind, sizeof(iptBind) - 1)
		if not imgui.IsItemActive() and iptTmp.iptBind ~= str(iptBind) then
			iptTmp.iptBind = str(iptBind)
		end

		imgui.SameLine()
		if imgui.Button('Добавить'..id_name..'button_Ss2', imgui.ImVec2(70,20)) then
			if hotkey.List['addNewBtn'].keys[1] and iptTmp.iptBind ~= '' then
				table.insert(keybincfg, {hotkey.List['addNewBtn'].keys, iptTmp.iptBind})
				iptTmp.iptBind = nil
				hotkey.List['addNewBtn'].keys = {}
				saveFile('keyBind.cfg', newsKeyBind)
			end
		end
		imgui.Tooltip('Добавить новый биндер\n\n*Поля не должны быть пустыми')

		imgui.TextCenter('{F9FFFF88}Настройки кнопок для биндера')
		imgui.BeginChild(id_name..'child_window_26', imgui.ImVec2(imgui.GetWindowWidth(), imgui.GetWindowHeight() - 42), false)
			local centSize = (imgui.GetWindowWidth() - (math.floor((imgui.GetWindowWidth() + 6) / 270) * 270 - 6)) / 2
			imgui.SetCursorPosX(centSize)

			for i, btn in ipairs(keybincfg) do
				hotkey.List['bindCfg_'..i] = hotkey.List['bindCfg_'..i] or {['keys'] = btn[1], ['callback'] = nil}
				if KeyEditor('bindCfg_'..i, nil, imgui.ImVec2(80,20)) then
					keybincfg[i][1] = hotkey.List['bindCfg_'..i].keys
					saveFile('keyBind.cfg', newsKeyBind)
				end

				imgui.SameLine(0)
				imgui.StrCopy(iptBind, btn[2])
				imgui.PushItemWidth(130)
				imgui.InputText(id_name..'input_BindB_'..i, iptBind, sizeof(iptBind) - 1)
				if not imgui.IsItemActive() and btn[2] and btn[2] ~= str(iptBind) then
					keybincfg[i][2] = str(iptBind)
					saveFile('keyBind.cfg', newsKeyBind)
				end

				imgui.SameLine()
				if imgui.Button('Х'..id_name..'button_Sb_'..i, imgui.ImVec2(20,20)) then
					table.remove(keybincfg, i)
					clearButtons()
					saveFile('keyBind.cfg', newsKeyBind)
					break
				end
				imgui.Tooltip('Удалить')

				if math.fmod(i, math.floor((imgui.GetWindowWidth() + 6) / 270)) ~= 0 then 
					imgui.SameLine()
					imgui.Text(i ~= #keybincfg and '|' or '')
					imgui.SameLine()
				else 
					imgui.SetCursorPosX(centSize)
				end
			end
		imgui.EndChild()
	imgui.EndChild()

end
function imgui.LocalEsters() -- Подраздел Эфиры
	imgui.SetCursorPosX(18)
	if imgui.HeaderButton(buttonPagesEf[5], ' Настройки ') then
		buttonPagesEf = {false, false, false, false, true}
	end
	imgui.SameLine()
	imgui.SetCursorPosX(imgui.GetWindowWidth() / 2 - 132)
	if imgui.HeaderButton(buttonPagesEf[1], '  Мероприятия ') then
		buttonPagesEf = {true, false, false, false, false}
	end
	imgui.SameLine()
	if imgui.HeaderButton(buttonPagesEf[2], ' Реклама ') then
		buttonPagesEf = {false, true, false, false, false}
	end
	imgui.SameLine()
	if imgui.HeaderButton(buttonPagesEf[3], ' Интерьвью ') then
		buttonPagesEf = {false, false, true, false, false}
	end
	imgui.SameLine()
	if imgui.HeaderButton(buttonPagesEf[4], ' Погода ') then
		buttonPagesEf = {false, false, false, true, false}
	end
	imgui.SetCursorPosY(32)

	if buttonPagesEf[1] then imgui.Events()
	elseif buttonPagesEf[2] then imgui.Text('Скоро..')
	elseif buttonPagesEf[3] then imgui.Text('Скоро..')
	elseif buttonPagesEf[4] then imgui.Text('Скоро..')
	elseif buttonPagesEf[5] then imgui.EventsSetting() end
end
function imgui.EventsSetting() -- раздел эфир. Настройки
	imgui.BeginChild(id_name..'child_window_13', imgui.ImVec2(imgui.GetWindowWidth() - 12, imgui.GetWindowHeight() - 40), false)
		for i, tag in ipairs({{'name','Имя и фамилия'},{'duty','Должность (с маленькой буквы)'},{'tagCNN','Тег в "/d" (без "[]")'},{'city','Город в котом СМИ'},{'server','Имя штата (сервер)'},{'music','Музыкальная заставка в эфире'}}) do
			imgui.SetCursorPosX(imgui.GetWindowWidth() / 2 - 160)
			imgui.PushItemWidth(180)
			imgui.StrCopy(inputEvSet, esterscfg.settings[tag[1]])
			imgui.InputText(id_name..'input_Es1_'..i, inputEvSet, sizeof(inputEvSet) - 1)
			if not imgui.IsItemActive() and esterscfg.settings[tag[1]] ~= str(inputEvSet) then
				esterscfg.settings[tag[1]] = str(inputEvSet)
				saveFile('estersBind.cfg', esterscfg)
			end
			if imgui.CalcTextSize(inputEvSet).x > 176 then
				imgui.Tooltip(str(inputEvSet))
			end
			imgui.SameLine()
			imgui.Text(tag[2])
		end
		imgui.SetCursorPosX(imgui.GetWindowWidth() / 2 - 160)
		imgui.SliderInt(' Задержка для отправки сообщений'..id_name..'slider_1', msgDelay, 1, 12, '%d sec')
		if not imgui.IsItemActive() and esterscfg.settings.delay ~= msgDelay[0] then
			if msgDelay[0] < 1 or msgDelay[0] > 12 then
				msgDelay[0] = esterscfg.settings.delay
				return
			end
			esterscfg.settings.delay = msgDelay[0]
			saveFile('estersBind.cfg', esterscfg)
		end
	imgui.EndChild()
end
function imgui.Events() -- Подраздел эфир. Мероприятия
	imgui.BeginChild(id_name..'child_window_8', imgui.ImVec2(imgui.GetWindowWidth() - 12, imgui.GetWindowHeight() - 40), false)
		imgui.BeginChild(id_name .. 'child_window_9', imgui.ImVec2(88, imgui.GetWindowHeight()), false, imgui.WindowFlags.NoScrollbar)
			imgui.SetCursorPosX(1)
			imgui.CustomMenu({
				' Описание',
				' Математика',
				' Столицы',
				' Прятки',
				' Приветы',
				' Химические\n   элементы',
				' Переводчики',
				' Зеркало',
				--' !Автор',
				--'       !Угадай\n  знаменитость',
				--'       !Знаток\n  автомобилей',
				--' !Крокодил',
				--' !О спорте',
				--' !Меломан',
				--'   !Правда\n или ложь?',
				--' !Cтендап'
			}, eventPages, imgui.ImVec2(88, 32), 0.08, true, 0, {
				'',
				'Математика - ведущий называет математический\nпример, а слушатели дают ответ. (Пример: 10+10-20)',
				'Столицы - ведущий называет страну в любой точке\nмира, а граждане должны ответить её столицу.\n(Пример: США - Вашингтон)',
				'Прятки - ведущий прячется в одной из точек\nштата, а задача слушателей найти его с\nпомощью указанных подсказок.',
				'Приветы и поздравления - слушатели звонят\nпо номеру радиостанции и передают приветы\nзнакомым, а также поздравляют их со\nзначимыми событиями.',
				'Химические элементы - ведущий называет\nкакой-либо хим. элемент из периодической\nтаблицы Д.И. Менделеева, а граждани дают\nответ. (Пример: Zn - цинк)', 
				'Переводчик - ведущий называет слова на\nанглийском / японском / итальянском языках,\nа задача слушателей написать правильный\nперевод на русский в СМС - сообщении\nна номер радиостанции.',
				'Зеркало - ведущий называет слово, а\nслушатели должны прислать ответ на\nномер радиостанции в виде\nСМС - сообщения с написанием этого\nслова задом наперёд.',
				'Автор - ведущий называет книгу, участник\nдолжен отгадать кто её написал.\n(Пример: «Код да Винчи» - ответ Дэн Браун,\n«Истории о том о сём» - ответ Том Хэнкс.)',
				'Угадай знаменитость - ведущий даёт описание\nкакой-нибудь знаменитой личности штата, а\nзадача слушателей назвать его/её имя и\nфамилию в СМС - сообщении на номер радиостанции.',
				'Знаток автомобилей - ведущий описывает\nмодель автомобиля, его характеристики, а\nслушатели должны написать название авто\nв СМС - сообщении на номер радиостанции.', 
				'Крокодил - Ведущий загадывает слово\nи описывает его, а участник должен\nугадать, что это за слово.', 
				'О спорте - ведущий задаёт вопросы на\nспортивную тематику, а задача\nслушателей написать верный ответ\nв СМС-сообщении на вопрос или\nпозвонить на номер радиостанции.',
				'Меломан - ведущий задаёт вопросы на тему\nмузыки, а задача слушателей написать верный\nответ в СМС - сообщении на вопрос или\nпозвонить на номер радиостанции.',
				'Правда или ложь? - ведущий задаёт вопрос\nо верном или неверном утверждении, а\nслушатели должны написать\nСМС-сообщение / позвонить на номер\nрадиостанции, верно ли утверждение или же нет.', 
				'Stand-Up - Подготовка небольших шуток,\nс трансляцией их в эфир.\nРазвлекать слушателей всеми силами,\nимпровизировать, принимать звонки\nи по-доброму подшучивать над\nдозвонившимися, рассказывая\nразличные истории.'
			})
		imgui.EndChild()
		imgui.SameLine()
		imgui.SetCursorPosX(100)
		imgui.BeginChild(id_name .. 'child_window_10', imgui.ImVec2(imgui.GetWindowWidth() - 100, imgui.GetWindowHeight()), false, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)
			if eventPages[0] == 1 then imgui.EventDescription()
				elseif eventPages[0] == 2 then imgui.Mathematics()
				elseif eventPages[0] == 3 then imgui.Capitals()
				elseif eventPages[0] == 4 then imgui.ToHide()
				elseif eventPages[0] == 5 then imgui.Greetings()
				elseif eventPages[0] == 6 then imgui.ChemicElements()
				elseif eventPages[0] == 7 then imgui.Interpreter()
				elseif eventPages[0] == 8 then imgui.Mirror()
				elseif eventPages[0] == 9 then imgui.Text('Скоро..')
				elseif eventPages[0] == 10 then imgui.Text('Скоро..')
				elseif eventPages[0] == 11 then imgui.Text('Скоро..')
				elseif eventPages[0] == 12 then imgui.Text('Скоро..')
				elseif eventPages[0] == 13 then imgui.Text('Скоро..')
				elseif eventPages[0] == 14 then imgui.Text('Скоро..')
				elseif eventPages[0] == 15 then imgui.Text('Скоро..')
				elseif eventPages[0] == 16 then imgui.Text('Скоро..')
				elseif eventPages[0] == 17 then imgui.Text('Скоро..') 
			end
		imgui.EndChild()
	imgui.EndChild()

end
function imgui.EventDescription() -- раздел мер. эфир. Описание
	imgui.NewLine()
	imgui.SetCursorPosX(20)
	imgui.BeginChild(id_name..'child_window_23', imgui.ImVec2(imgui.GetWindowWidth() - 40, imgui.GetWindowHeight() - 38), false)
		imgui.TextWrapped('Эфиры находятся в тестовом варианте, вы можете их использовать. Однака сначала проверяйте текст перед использованием его в эфире! На всех серверах разные правила и теги.')
		imgui.TextStart('{b5e530cb}Вы можете изменять текст эфиров! Теги вы тоже можете изменять!')
		imgui.NewLine()
		imgui.TextWrapped('Если вы столкнетесь с багами или вам будет не удобно использовать данный биндер, обязательно напиши, что именно тут не так!')
		imgui.SetCursorPosY(imgui.GetWindowHeight() - 30)
		imgui.TextWrapped('p.s. я не играю в самп и никогда не состоял в СМИ, так что не знаю, удобно вам или нет. Обязательно дайте обратную связь!')
	imgui.EndChild()
end
function imgui.Mathematics() -- раздел мер. эфир. Математика
	imgui.BeginChild(id_name..'child_window_11', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3) * 2 - 8, imgui.GetWindowHeight()), false)
		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptID = new.char[256]('')
		imgui.StrCopy(iptID, iptTmp.iptID or '')
		if imgui.InputText(id_name..'input_9', iptID, sizeof(iptID) - 1, 16) then
			iptTmp.iptID = str(iptID)
			tmp.evNick = nil
			if tonumber(str(iptID)) and sampIsPlayerConnected(str(iptID)) then
				tmp.evNick = sampGetPlayerNickname(str(iptID)):gsub('_', ' '):gsub('^%[%d%d?%]', '')
			end
		end
		imgui.SameLine()
		imgui.Text('ID игрока')
		imgui.Tooltip('ID для взаимодействия с человеком')

		imgui.SameLine()

		imgui.SetCursorPosX(imgui.GetWindowWidth() - 142)
		imgui.Text('Награда')
		imgui.Tooltip('Напишите сюда награду за эфир')
		imgui.SameLine()
		imgui.PushItemWidth(80)
		local iptPrz = new.char[256]('')
		imgui.StrCopy(iptPrz, iptTmp.iptPrz or '1 млн')
		if imgui.InputText(id_name..'input_11', iptPrz, sizeof(iptPrz) - 1) then
			iptTmp.iptPrz = str(iptPrz)
		end

		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptScrId = new.char[256]('')
		imgui.StrCopy(iptScrId, iptTmp.iptScrId or '')
		if imgui.InputText(id_name..'input_10', iptScrId, sizeof(iptScrId) - 1, 16) then
			iptTmp.iptScrId = str(iptScrId)
		end
		imgui.SameLine()
		imgui.Text('Кол-во баллов')
		imgui.Tooltip('Сколько у человека баллов?')

		imgui.SameLine()

		imgui.SetCursorPosX(imgui.GetWindowWidth() - 88)
		imgui.Text('Раунды')
		imgui.Tooltip('До скольки баллов будем играть?')
		imgui.SameLine()
		imgui.PushItemWidth(30)
		local iptScr = new.char[256]('')
		imgui.StrCopy(iptScr, iptTmp.iptScr or '5')
		if imgui.InputText(id_name..'input_12', iptScr, sizeof(iptScr) - 1) then
			iptTmp.iptScr = str(iptScr)
		end

		imgui.RenderButtonEf(esterscfg.events.mathem, {
			{'prize', iptTmp.iptPrz or '1 млн', '1 млн', 'У вас не указанна {fead00}награда{C0C0C0} за данный эфир!', 'Награда за эфир'},
			{'scores', iptTmp.iptScr or '5', '3', 'У вас не указанно сколько {fead00}раундов{C0C0C0} будет в эфире!', 'Количество раундов'},
			{'scoreID', iptTmp.iptScrId, '2', 'У вас не указанно сколько {fead00}баллов{C0C0C0} у человека!', 'Количество баллов у человека'},
			{'ID', tmp.evNick, 'Rudius Greyrat', 'У вас не указан {fead00}ID{C0C0C0} человека!', 'Имя человека'}
		})
	imgui.EndChild()

	imgui.SameLine()

	imgui.BeginChild(id_name..'child_window_12', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3), imgui.GetWindowHeight()), false)
		imgui.TextCenter('Калькулятор')

		imgui.SetCursorPos(imgui.ImVec2(8, imgui.GetCursorPosY() + 6))
		imgui.PushItemWidth(imgui.GetWindowWidth() - 20 - 4 - 18)
		local iptCal1 = new.char[256]('')
		imgui.StrCopy(iptCal1, iptTmp.iptCal1 or '')
		if imgui.InputTextWithHint(id_name..'input_13', '10+2^(10/2)*1.5', iptCal1, sizeof(iptCal1) - 1, imgui.InputTextFlags.CallbackAlways, callbacks.calc) then
			iptTmp.iptCal1 = str(iptCal1):gsub('[^%d%+%-%^%/%(%)%*%s%.]+', '')
			local calc = load('return '..iptTmp.iptCal1);
			local resul = tostring(calc and calc() or 'Ошибка')
			if resul == 'nan' or resul == 'inf' then resul = ' /0 = err' end
			iptTmp.iptCal2 = (iptTmp.iptCal1 ~= '' and resul or '')
		end
		imgui.Tooltip('Введите математический\nпример, доступные символы:\n\n + прибавить\n - вычесть\n * умножить\n / разделить (наклон важен!)\n ^ возвести в степень\n () для первенства выражения')

		imgui.SameLine(nil, 4)
		if imgui.Button('Х'..id_name..'button_12', imgui.ImVec2(18,20)) then
			iptTmp.iptCal1 = nil
			iptTmp.iptCal2 = nil
		end
		imgui.Tooltip('Очистить')

		imgui.SetCursorPosX(8)
		imgui.Text('Результат')
		imgui.SameLine()
		imgui.PushItemWidth(imgui.GetWindowWidth() - 20 - 67)
		local iptCal2 = new.char[256]('')
		imgui.StrCopy(iptCal2, iptTmp.iptCal2 or '')
		imgui.InputText(id_name..'input_14', iptCal2, sizeof(iptCal2) - 1, imgui.InputTextFlags.ReadOnly)

		imgui.SetCursorPosY(imgui.GetCursorPosY() + 6)
		imgui.Separator()
		imgui.SetCursorPosY(imgui.GetCursorPosY() + 4)

		imgui.MeNotepad('mathem')
	imgui.EndChild()
end
function imgui.ChemicElements() -- раздел мер. эфир. Химические элементы
	imgui.BeginChild(id_name..'child_window_17', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3) * 2 - 8, imgui.GetWindowHeight()), false)
		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptID = new.char[256]('')
		imgui.StrCopy(iptID, iptTmp.iptID or '')
		if imgui.InputText(id_name..'input_9', iptID, sizeof(iptID) - 1, 16) then
			iptTmp.iptID = str(iptID)
			tmp.evNick = nil
			if tonumber(str(iptID)) and sampIsPlayerConnected(str(iptID)) then
				tmp.evNick = sampGetPlayerNickname(str(iptID)):gsub('_', ' '):gsub('^%[%d%d?%]', '')
			end
		end
		imgui.SameLine()
		imgui.Text('ID игрока')
		imgui.Tooltip('ID для взаимодействия с человеком')

		imgui.SameLine()

		imgui.SetCursorPosX(imgui.GetWindowWidth() - 142)
		imgui.Text('Награда')
		imgui.Tooltip('Напишите сюда награду за эфир')
		imgui.SameLine()
		imgui.PushItemWidth(80)
		local iptPrz = new.char[256]('')
		imgui.StrCopy(iptPrz, iptTmp.iptPrz or '1 млн')
		if imgui.InputText(id_name..'input_11', iptPrz, sizeof(iptPrz) - 1) then
			iptTmp.iptPrz = str(iptPrz)
		end

		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptScrId = new.char[256]('')
		imgui.StrCopy(iptScrId, iptTmp.iptScrId or '')
		if imgui.InputText(id_name..'input_10', iptScrId, sizeof(iptScrId) - 1, 16) then
			iptTmp.iptScrId = str(iptScrId)
		end
		imgui.SameLine()
		imgui.Text('Кол-во баллов')
		imgui.Tooltip('Сколько у человека баллов?')

		imgui.SameLine()

		imgui.SetCursorPosX(imgui.GetWindowWidth() - 88)
		imgui.Text('Раунды')
		imgui.Tooltip('До скольки баллов будем играть?')
		imgui.SameLine()
		imgui.PushItemWidth(30)
		local iptScr = new.char[256]('')
		imgui.StrCopy(iptScr, iptTmp.iptScr or '5')
		if imgui.InputText(id_name..'input_12', iptScr, sizeof(iptScr) - 1) then
			iptTmp.iptScr = str(iptScr)
		end

		imgui.RenderButtonEf(esterscfg.events.chemic, {
			{'prize', iptTmp.iptPrz or '1 млн', '1 млн', 'У вас не указанна {fead00}награда{C0C0C0} за данный эфир!', 'Награда за эфир'},
			{'scores', iptTmp.iptScr or '5', '3', 'У вас не указанно сколько {fead00}раундов{C0C0C0} будет в эфире!', 'Количество раундов'},
			{'scoreID', iptTmp.iptScrId, '2', 'У вас не указанно сколько {fead00}баллов{C0C0C0} у человека!', 'Количество баллов у человека'},
			{'ID', tmp.evNick, 'Rudius Greyrat', 'У вас не указан {fead00}ID{C0C0C0} человека!', 'Имя человека'}
		})
	imgui.EndChild()

	imgui.SameLine()

	imgui.BeginChild(id_name..'child_window_18', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3), imgui.GetWindowHeight()), false)
		local chemicElem = {'H = Водород', 'He = Гелий', 'Li = Литий', 'Be = Берилий', 'B = Бор', 'C = Углерод', 'N = Азот', 'O = Кислород',
			'F = Фтор', 'Ne = Неон', 'Na = Натрий', 'Mg = Магний', 'Al = Алюминий', 'Si = Кремний', 'P = Фосфор', 'S = Сера', 'Cl = Хлор',
			'Ar = Аргон', 'K = Калий', 'Ca = Кальций', 'Sc = Скандий', 'Ti = Титан', 'V = Ванадий', 'Cr = Хром', 'Mn = Марганец', 'Fe = Железо',
			'Co = Кобальт', 'Cu = Медь', 'Zn = Цинк', 'Ga = Галий', 'Ge = Германий', 'As = Мышьяк', 'Se = Селен', 'Br = Бром', 'Kr = Криптон'
		}
		imgui.BeginChild(id_name..'child_window_24', imgui.ImVec2(imgui.GetWindowWidth(), imgui.GetWindowHeight() / 2 - 10), false)
			for i, element in ipairs(chemicElem) do
				local txtChat = '/news '..esterscfg.events.chemic.tag..element:sub(1, element:find(' ')-1)..' = ?'
				if imgui.Selectable(id_name..'selec_table_HIM_'..i, nil) then
					sampSetChatInputEnabled(true)
					sampSetChatInputText(u8:decode(txtChat))
				end
				imgui.Tooltip('Крикабельно, вставит в чат:\n\n'..txtChat)
				imgui.SameLine(nil, imgui.GetWindowWidth() / 2 - 45)
				imgui.Text(element)
			end
		imgui.EndChild()

		imgui.SetCursorPosY(imgui.GetCursorPosY() + 6)
		imgui.Separator()
		imgui.SetCursorPosY(imgui.GetCursorPosY() + 4)

		imgui.MeNotepad('chemic')
	imgui.EndChild()
end
function imgui.Greetings() -- раздел мер. эфир. Приветы
	imgui.BeginChild(id_name..'child_window_19', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3) * 2 - 8, imgui.GetWindowHeight()), false)
		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptID = new.char[256]('')
		imgui.StrCopy(iptID, iptTmp.iptID or '')
		if imgui.InputText(id_name..'input_9', iptID, sizeof(iptID) - 1, 16) then
			iptTmp.iptID = str(iptID)
			tmp.evNick = nil
			if tonumber(str(iptID)) and sampIsPlayerConnected(str(iptID)) then
				tmp.evNick = sampGetPlayerNickname(str(iptID)):gsub('_', ' '):gsub('^%[%d%d?%]', '')
			end
		end
		imgui.SameLine()
		imgui.Text('ID передает')
		imgui.Tooltip('ID человека, который передает привет')

		imgui.SameLine()

		imgui.SetCursorPosX(imgui.GetWindowWidth() - 81)
		imgui.Text('Время')
		imgui.Tooltip('Сколько будет идти данный эфир?')
		imgui.SameLine()
		imgui.PushItemWidth(30)
		local iptTime = new.char[256]('')
		imgui.StrCopy(iptTime, iptTmp.iptTime or '15')
		if imgui.InputText(id_name..'input_12', iptTime, sizeof(iptTime) - 1) then
			iptTmp.iptTime = str(iptTime)
		end

		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptToId = new.char[256]('')
		imgui.StrCopy(iptToId, iptTmp.iptToId or '')
		if imgui.InputText(id_name..'input_10', iptToId, sizeof(iptToId) - 1, 16) then
			iptTmp.iptToId = str(iptToId)
			tmp.evNick2 = nil
			if tonumber(str(iptToId)) and sampIsPlayerConnected(str(iptToId)) then
				tmp.evNick2 = sampGetPlayerNickname(str(iptToId)):gsub('_', ' '):gsub('^%[%d%d?%]', '')
			end
		end
		imgui.SameLine()
		imgui.Text('ID получает')
		imgui.Tooltip('ID человека, который получает привет')

		imgui.RenderButtonEf(esterscfg.events.greet, {
			{'time', iptTmp.iptTime or '15', '30', 'У вас не указанно сколько {fead00}времени{C0C0C0} будет этот эфир!', 'Время длительности эфира'},
			{'toID', tmp.evNick2, 'Sharky Flint', 'У вас не указанно {fead00}ID кому{C0C0C0} передают привет!', 'Имя КОМУ передают привет'},
			{'ID', tmp.evNick, 'Rudius Greyrat', 'У вас не указан {fead00}ID кто{C0C0C0} передает привет!', 'Имя КТО передает привет'}
		}, {
			{'Передать привет', true, function (txt, tCon)
				for i, lTags in ipairs(tCon) do
					if lTags[1] == 'ID' and not lTags[2] then
						lTags[2] = '*'
					end
					if lTags[1] == 'toID' and not lTags[2] then
						lTags[2] = '*'
					end
					tCon[i] = lTags
				end
				local chTxt = regexTag(txt[2], tCon)
				sampSetChatInputEnabled(true)
				sampSetChatInputText(u8:decode(''..chTxt:gsub('%*', '', 1)))
				if chTxt:find('%*') then setChatCursorPos(utf8len(chTxt:match('(.-)%*'))) end
			end}
		})
	imgui.EndChild()

	imgui.SameLine()

	imgui.BeginChild(id_name..'child_window_20', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3), imgui.GetWindowHeight()), false)
		imgui.MeNotepad('greet')
	imgui.EndChild()
end
function imgui.ToHide() -- раздел мер. эфир. Прятки
	imgui.BeginChild(id_name..'child_window_19', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3) * 2 - 8, imgui.GetWindowHeight()), false)
		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptID = new.char[256]('')
		imgui.StrCopy(iptID, iptTmp.iptID or '')
		if imgui.InputText(id_name..'input_9', iptID, sizeof(iptID) - 1, 16) then
			iptTmp.iptID = str(iptID)
			tmp.evNick = nil
			if tonumber(str(iptID)) and sampIsPlayerConnected(str(iptID)) then
				tmp.evNick = sampGetPlayerNickname(str(iptID)):gsub('_', ' '):gsub('^%[%d%d?%]', '')
			end
		end
		imgui.SameLine()
		imgui.Text('ID игрока')
		imgui.Tooltip('ID для взаимодействия с человеком')

		imgui.SameLine()

		imgui.SetCursorPosX(imgui.GetWindowWidth() - 142)
		imgui.Text('Награда')
		imgui.Tooltip('Напишите сюда награду за эфир')
		imgui.SameLine()
		imgui.PushItemWidth(80)
		local iptPrz = new.char[256]('')
		imgui.StrCopy(iptPrz, iptTmp.iptPrz or '1 млн')
		if imgui.InputText(id_name..'input_11', iptPrz, sizeof(iptPrz) - 1) then
			iptTmp.iptPrz = str(iptPrz)
		end

		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(138)
		local iptPhrase = new.char[256]('')
		imgui.StrCopy(iptPhrase, iptTmp.iptPhrase or '')
		if imgui.InputTextWithHint(id_name..'input_10', 'Вкусная клубника', iptPhrase, sizeof(iptPhrase) - 1) then
			iptTmp.iptPhrase = str(iptPhrase)
		end
		imgui.SameLine()
		imgui.Text('Фраза')
		imgui.Tooltip('Фраза, которую человек должен\nсказать как приблизится к вам!')

		imgui.SameLine()

		imgui.SetCursorPosX(imgui.GetWindowWidth() - 81)
		imgui.Text('Время')
		imgui.Tooltip('Сколько будет идти данный эфир?')
		imgui.SameLine()
		imgui.PushItemWidth(30)
		local iptTime = new.char[256]('')
		imgui.StrCopy(iptTime, iptTmp.iptTime or '50')
		if imgui.InputText(id_name..'input_12', iptTime, sizeof(iptTime) - 1) then
			iptTmp.iptTime = str(iptTime)
		end

		imgui.RenderButtonEf(esterscfg.events.tohide, {
			{'prize', iptTmp.iptPrz or '1 млн', '1 млн', 'У вас не указана {fead00}награда{C0C0C0} за данный эфир!', 'Награда за эфир'},
			{'time', iptTmp.iptTime or '50', '40', 'У вас не указанно сколько {fead00}времени{C0C0C0} будет этот эфир!', 'Длительность эфира'},
			{'phrase', iptTmp.iptPhrase, 'Вкусная клубника', 'У вас не указана {fead00}фраза{C0C0C0} которую нужно сказать!', 'Фраза которую нужно озвучить'},
			{'ID', tmp.evNick, 'Rudius Greyrat', 'У вас не указан {fead00}ID{C0C0C0} человека!', 'Имя человека'}
		})
	imgui.EndChild()

	imgui.SameLine()

	imgui.BeginChild(id_name..'child_window_20', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3), imgui.GetWindowHeight()), false)
		imgui.MeNotepad('tohide')
	imgui.EndChild()
end
function imgui.Capitals() -- раздел мер. эфир. Столицы
	imgui.BeginChild(id_name..'child_window_27', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3) * 2 - 8, imgui.GetWindowHeight()), false)
		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptID = new.char[256]('')
		imgui.StrCopy(iptID, iptTmp.iptID or '')
		if imgui.InputText(id_name..'input_9', iptID, sizeof(iptID) - 1, 16) then
			iptTmp.iptID = str(iptID)
			tmp.evNick = nil
			if tonumber(str(iptID)) and sampIsPlayerConnected(str(iptID)) then
				tmp.evNick = sampGetPlayerNickname(str(iptID)):gsub('_', ' '):gsub('^%[%d%d?%]', '')
			end
		end
		imgui.SameLine()
		imgui.Text('ID игрока')
		imgui.Tooltip('ID для взаимодействия с человеком')

		imgui.SameLine()

		imgui.SetCursorPosX(imgui.GetWindowWidth() - 142)
		imgui.Text('Награда')
		imgui.Tooltip('Напишите сюда награду за эфир')
		imgui.SameLine()
		imgui.PushItemWidth(80)
		local iptPrz = new.char[256]('')
		imgui.StrCopy(iptPrz, iptTmp.iptPrz or '1 млн')
		if imgui.InputText(id_name..'input_11', iptPrz, sizeof(iptPrz) - 1) then
			iptTmp.iptPrz = str(iptPrz)
		end

		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptScrId = new.char[256]('')
		imgui.StrCopy(iptScrId, iptTmp.iptScrId or '')
		if imgui.InputText(id_name..'input_10', iptScrId, sizeof(iptScrId) - 1, 16) then
			iptTmp.iptScrId = str(iptScrId)
		end
		imgui.SameLine()
		imgui.Text('Кол-во баллов')
		imgui.Tooltip('Сколько у человека баллов?')

		imgui.SameLine()

		imgui.SetCursorPosX(imgui.GetWindowWidth() - 88)
		imgui.Text('Раунды')
		imgui.Tooltip('До скольки баллов будем играть?')
		imgui.SameLine()
		imgui.PushItemWidth(30)
		local iptScr = new.char[256]('')
		imgui.StrCopy(iptScr, iptTmp.iptScr or '5')
		if imgui.InputText(id_name..'input_12', iptScr, sizeof(iptScr) - 1) then
			iptTmp.iptScr = str(iptScr)
		end

		imgui.RenderButtonEf(esterscfg.events.capitals, {
			{'prize', iptTmp.iptPrz or '1 млн', '1 млн', 'У вас не указанна {fead00}награда{C0C0C0} за данный эфир!', 'Награда за эфир'},
			{'scores', iptTmp.iptScr or '5', '3', 'У вас не указанно сколько {fead00}раундов{C0C0C0} будет в эфире!', 'Количество раундов'},
			{'scoreID', iptTmp.iptScrId, '2', 'У вас не указанно сколько {fead00}баллов{C0C0C0} у человека!', 'Количество баллов у человека'},
			{'ID', tmp.evNick, 'Rudius Greyrat', 'У вас не указан {fead00}ID{C0C0C0} человека!', 'Имя человека'}
		})
	imgui.EndChild()

	imgui.SameLine()

	imgui.BeginChild(id_name..'child_window_28', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3), imgui.GetWindowHeight()), false)
		local capitalsCities = {
			'Австрия = Вена', 'Аргентина = Буэнос-Айрес', 'Армения = Ереван', 'Белоруссия = Минск', 'Бельгия = Брюссель', 'Болгария = София',
			'Великобритания = Лондон', 'Вьетнам = Ханой', 'Германия = Берлин', 'Греция = Афины', 'Грузия = Тбилиси', 'Дания = Копенгаген',
			'Египет = Каир', 'Индия = Нью-Дели', 'Ирак = Багдад', 'Иран = Тегеран', 'Испания = Мадрид', 'Канада = Оттава', 'Китай = Пекин',
			'Куба = Гавана', 'Латвия = Рига', 'Литва = Вильнюс', 'Мексика = Мехико', 'Молдавия = Кишинев', 'Монголия = Улан-Батор',
			'Нидерланды (Голландия) = Амстердам', 'Норвегия = Осло', 'Перу = Лима', 'Польша = Варшава', 'Португалия = Лиссабон',
			'Россия = Москва', 'США = Вашингтон', 'Сирия = Дамаск', 'Словакия = Братислава', 'Словения = Любляна', 'Тунис = Тунис',
			'Турция = Анкара', 'Украина = Киев', 'Уругвай = Монтевидео', 'Финляндия = Хельсинки', 'Франция = Париж', 'Хорватия = Загреб',
			'Чехия = Прага', 'Чили = Сантьяго', 'Швейцария = Берн', 'Швеция = Стокгольм', 'Эстония = Таллин', 'Япония = Токио'
		}
		imgui.BeginChild(id_name..'child_window_24', imgui.ImVec2(imgui.GetWindowWidth(), imgui.GetWindowHeight() / 2 - 10), false)
			for i, capital in ipairs(capitalsCities) do
				local txtChat = '/news '..esterscfg.events.capitals.tag..capital:sub(1, capital:find(' ')-1)..' = ?'
				if imgui.Selectable(id_name..'selec_table_HIM_'..i, nil) then
					sampSetChatInputEnabled(true)
					sampSetChatInputText(u8:decode(txtChat))
				end
				imgui.Tooltip('Крикабельно, вставит в чат:\n\n'..txtChat)
				imgui.SameLine(nil, imgui.GetWindowWidth() / 2 - 80)
				imgui.Text(capital)
			end
		imgui.EndChild()

		imgui.SetCursorPosY(imgui.GetCursorPosY() + 6)
		imgui.Separator()
		imgui.SetCursorPosY(imgui.GetCursorPosY() + 4)


		imgui.MeNotepad('capitals')
	imgui.EndChild()
end
function imgui.Interpreter() -- раздел мер. эфир. Переводчик
	imgui.BeginChild(id_name..'child_window_11', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3) * 2 - 8, imgui.GetWindowHeight()), false)
		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptID = new.char[256]('')
		imgui.StrCopy(iptID, iptTmp.iptID or '')
		if imgui.InputText(id_name..'input_9', iptID, sizeof(iptID) - 1, 16) then
			iptTmp.iptID = str(iptID)
			tmp.evNick = nil
			if tonumber(str(iptID)) and sampIsPlayerConnected(str(iptID)) then
				tmp.evNick = sampGetPlayerNickname(str(iptID)):gsub('_', ' '):gsub('^%[%d%d?%]', '')
			end
		end
		imgui.SameLine()
		imgui.Text('ID игрока')
		imgui.Tooltip('ID для взаимодействия с человеком')

		imgui.SameLine()

		imgui.SetCursorPosX(imgui.GetWindowWidth() - 142)
		imgui.Text('Награда')
		imgui.Tooltip('Напишите сюда награду за эфир')
		imgui.SameLine()
		imgui.PushItemWidth(80)
		local iptPrz = new.char[256]('')
		imgui.StrCopy(iptPrz, iptTmp.iptPrz or '1 млн')
		if imgui.InputText(id_name..'input_11', iptPrz, sizeof(iptPrz) - 1) then
			iptTmp.iptPrz = str(iptPrz)
		end

		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptScrId = new.char[256]('')
		imgui.StrCopy(iptScrId, iptTmp.iptScrId or '')
		if imgui.InputText(id_name..'input_10', iptScrId, sizeof(iptScrId) - 1, 16) then
			iptTmp.iptScrId = str(iptScrId)
		end
		imgui.SameLine()
		imgui.Text('Кол-во баллов')
		imgui.Tooltip('Сколько у человека баллов?')

		imgui.SameLine()

		imgui.SetCursorPosX(imgui.GetWindowWidth() - 88)
		imgui.Text('Раунды')
		imgui.Tooltip('До скольки баллов будем играть?')
		imgui.SameLine()
		imgui.PushItemWidth(30)
		local iptScr = new.char[256]('')
		imgui.StrCopy(iptScr, iptTmp.iptScr or '5')
		if imgui.InputText(id_name..'input_12', iptScr, sizeof(iptScr) - 1) then
			iptTmp.iptScr = str(iptScr)
		end

		imgui.SetCursorPosX(imgui.GetWindowWidth() / 2 - 75)
		imgui.PushItemWidth(120)
		imgui.Combo('Язык'..id_name..'combo_1', ComboLanguage, languageItems, #languageList)

		imgui.RenderButtonEf(esterscfg.events.interpreter, {
			{'prize', iptTmp.iptPrz or '1 млн', '1 млн', 'У вас не указанна {fead00}награда{C0C0C0} за данный эфир!', 'Награда за эфир'},
			{'scores', iptTmp.iptScr or '5', '3', 'У вас не указанно сколько {fead00}раундов{C0C0C0} будет в эфире!', 'Количество раундов'},
			{'scoreID', iptTmp.iptScrId, '2', 'У вас не указанно сколько {fead00}баллов{C0C0C0} у человека!', 'Количество баллов у человека'},
			{'language', languageList[ComboLanguage[0]+1]:match('(.+)....'), 'Английск', 'У вас не указан {fead00}Язык{C0C0C0} данного эфира!', 'Язык на котором будут слова\nОбратите внимание, что нет окончания!'},
			{'ID', tmp.evNick, 'Rudius Greyrat', 'У вас не указан {fead00}ID{C0C0C0} человека!', 'Имя человека'}
		})
	imgui.EndChild()

	imgui.SameLine()

	imgui.BeginChild(id_name..'child_window_12', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3), imgui.GetWindowHeight()), false)
		if imgui.BeginTabBar(id_name..'tabbar_1') then
			if imgui.BeginTabItem(' Перевод '..id_name..'tabitem_1') then
				imgui.TextCenter('Переводчик')

				imgui.SetCursorPos(imgui.ImVec2(8, imgui.GetCursorPosY() + 6))
				imgui.PushItemWidth(imgui.GetWindowWidth() - 20 - 4 - 18)
				local iptTrnsl = new.char[32]('')
				imgui.StrCopy(iptTrnsl, iptTmp.iptTrnsl or '')
				if imgui.InputTextWithHint(id_name..'input_13', 'Шоколад', iptTrnsl, sizeof(iptTrnsl) - 1, imgui.InputTextFlags.CharsNoBlank) then
					iptTmp.iptTrnsl = str(iptTrnsl)
				end
				imgui.Tooltip('Введите любое слово,\n  мы его переведём!')

				imgui.SameLine(nil, 4)
				if imgui.Button('Х'..id_name..'button_12', imgui.ImVec2(18, 20)) then
					iptTmp.iptTrnsl = nil
					tmp.Trnsl = nil
				end
				imgui.Tooltip('Очистить')

				imgui.SetCursorPos(imgui.ImVec2(8, imgui.GetCursorPosY() + 3))
				if imgui.Button('Перевести'..id_name..'button_19', imgui.ImVec2(imgui.GetWindowWidth() - 20, 20)) and iptTmp.iptTrnsl and iptTmp.iptTrnsl ~= '' then
					lua_thread.create(function (word, lang, tmp)
						local st, func = pcall(loadstring, [[return {translate=function(txt, langTag, tmp)local commonAnswer = true local tName = os.tmpname()if doesFileExist(tName)then os.remove(tName)end downloadUrlToFile('https://translate.googleapis.com/translate_a/single?'..httpBuild({['client'] = 'gtx', ['dt'] = 't', ['sl'] = 'ru', ['tl'] = langTag, ['q'] = txt}), tName, function (_, st)if st==58 then if doesFileExist(tName)then local tFile=io.open(tName, 'r')if tFile then local answer=decodeJson(tFile:read('*a'))commonAnswer=(answer[1][1][1] and true or false)tmp.Trnsl=answer[1][1][1]or'Ошибка доступа!'tFile:close()os.remove(tName)end else tmp.Trnsl='Фатальная ошибка!'commonAnswer=false end end end)return commonAnswer end}]])
						if st then pcall(func().translate, word, lang, tmp) else tmp.Trnsl = 'Ошибка доступа!' end
					end, iptTmp.iptTrnsl, langArr.tags[ComboLanguage[0]+2], tmp)
				end

				if tmp.Trnsl then 
					local txtChat = '/news '..esterscfg.events.interpreter.tag..tmp.Trnsl..' = ?'
					imgui.SetCursorPos(imgui.ImVec2(8, imgui.GetCursorPosY() + 3))
					imgui.PushStyleColor(imgui.Col.HeaderHovered, imgui.ImVec4(0, 0, 0, 0))
					imgui.PushStyleColor(imgui.Col.HeaderActive, imgui.ImVec4(0, 0, 0, 0))
					if imgui.Selectable(id_name..'selec_table_Wt', nil) then
						sampSetChatInputEnabled(true)
						sampSetChatInputText(u8:decode(txtChat))
					end
					imgui.PopStyleColor(2)
					imgui.Tooltip('Крикабельно, вставит в чат:\n\n'..txtChat)
					imgui.SameLine(nil, imgui.GetWindowWidth() / 2 - imgui.CalcTextSize(tmp.Trnsl or ' ').x / 2 - 10)
					imgui.Text(tmp.Trnsl or ' ')
				end

				imgui.EndTabItem()
			end
			if imgui.BeginTabItem('Заготовки'..id_name..'tabitem_2') then
				imgui.BeginChild(id_name..'child_window_24', imgui.ImVec2(imgui.GetWindowWidth(), imgui.GetWindowHeight() / 2 - 10), false)
					for i, word in ipairs(langArr.ru) do
						local foreignW = langArr[langArr.tags[ComboLanguage[0]+2]][i]
						local txtChat = '/news '..esterscfg.events.interpreter.tag..foreignW..' = ?'
						if imgui.Selectable(id_name..'selec_table_W_'..i, nil) then
							sampSetChatInputEnabled(true)
							sampSetChatInputText(u8:decode(txtChat))
						end
						imgui.Tooltip('Крикабельно, вставит в чат:\n\n'..txtChat)
						imgui.SameLine(nil, imgui.GetWindowWidth() / 2 - 60)
						imgui.Text(word..' = '..foreignW)
					end
				imgui.EndChild()
				imgui.EndTabItem()
			end
			imgui.EndTabBar()
		end

		imgui.SetCursorPosY(imgui.GetCursorPosY() + 6)
		imgui.Separator()
		imgui.SetCursorPosY(imgui.GetCursorPosY() + 4)

		imgui.MeNotepad('interpreter')
	imgui.EndChild()
end
function imgui.Mirror() -- раздел мер. эфир. Зеркало
	imgui.BeginChild(id_name..'child_window_27', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3) * 2 - 8, imgui.GetWindowHeight()), false)
		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptID = new.char[256]('')
		imgui.StrCopy(iptID, iptTmp.iptID or '')
		if imgui.InputText(id_name..'input_9', iptID, sizeof(iptID) - 1, 16) then
			iptTmp.iptID = str(iptID)
			tmp.evNick = nil
			if tonumber(str(iptID)) and sampIsPlayerConnected(str(iptID)) then
				tmp.evNick = sampGetPlayerNickname(str(iptID)):gsub('_', ' '):gsub('^%[%d%d?%]', '')
			end
		end
		imgui.SameLine()
		imgui.Text('ID игрока')
		imgui.Tooltip('ID для взаимодействия с человеком')

		imgui.SameLine()

		imgui.SetCursorPosX(imgui.GetWindowWidth() - 142)
		imgui.Text('Награда')
		imgui.Tooltip('Напишите сюда награду за эфир')
		imgui.SameLine()
		imgui.PushItemWidth(80)
		local iptPrz = new.char[256]('')
		imgui.StrCopy(iptPrz, iptTmp.iptPrz or '1 млн')
		if imgui.InputText(id_name..'input_11', iptPrz, sizeof(iptPrz) - 1) then
			iptTmp.iptPrz = str(iptPrz)
		end

		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptScrId = new.char[256]('')
		imgui.StrCopy(iptScrId, iptTmp.iptScrId or '')
		if imgui.InputText(id_name..'input_10', iptScrId, sizeof(iptScrId) - 1, 16) then
			iptTmp.iptScrId = str(iptScrId)
		end
		imgui.SameLine()
		imgui.Text('Кол-во баллов')
		imgui.Tooltip('Сколько у человека баллов?')

		imgui.SameLine()

		imgui.SetCursorPosX(imgui.GetWindowWidth() - 88)
		imgui.Text('Раунды')
		imgui.Tooltip('До скольки баллов будем играть?')
		imgui.SameLine()
		imgui.PushItemWidth(30)
		local iptScr = new.char[256]('')
		imgui.StrCopy(iptScr, iptTmp.iptScr or '5')
		if imgui.InputText(id_name..'input_12', iptScr, sizeof(iptScr) - 1) then
			iptTmp.iptScr = str(iptScr)
		end

		imgui.RenderButtonEf(esterscfg.events.mirror, {
			{'prize', iptTmp.iptPrz or '1 млн', '1 млн', 'У вас не указанна {fead00}награда{C0C0C0} за данный эфир!', 'Награда за эфир'},
			{'scores', iptTmp.iptScr or '5', '3', 'У вас не указанно сколько {fead00}раундов{C0C0C0} будет в эфире!', 'Количество раундов'},
			{'scoreID', iptTmp.iptScrId, '2', 'У вас не указанно сколько {fead00}баллов{C0C0C0} у человека!', 'Количество баллов у человека'},
			{'ID', tmp.evNick, 'Rudius Greyrat', 'У вас не указан {fead00}ID{C0C0C0} человека!', 'Имя человека'}
		})
	imgui.EndChild()

	imgui.SameLine()

	imgui.BeginChild(id_name..'child_window_28', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3), imgui.GetWindowHeight()), false)
		imgui.TextCenter('Переворачивание слов')

		imgui.SetCursorPos(imgui.ImVec2(8, imgui.GetCursorPosY() + 6))
		imgui.PushItemWidth(imgui.GetWindowWidth() - 20 - 4 - 18)
		local iptMir1 = new.char[64]('')
		imgui.StrCopy(iptMir1, iptTmp.iptMir1 or '')
		if imgui.InputTextWithHint(id_name..'input_13', 'Привет', iptMir1, sizeof(iptMir1) - 1, imgui.InputTextFlags.CharsNoBlank) then
			iptTmp.iptMir1 = str(iptMir1)
			tmp.iptMir2 = nil
			if iptTmp.iptMir1 ~= '' then
				local inverted = u8:decode(iptTmp.iptMir1:nlower()):reverse()
				tmp.iptMir2 = u8:encode(inverted:match('^(.)')):nupper() .. u8:encode(inverted:match('^.(.*)'))
			end

		end
		imgui.Tooltip('Введите любое слово,\n  мы его перевернём!')

		imgui.SameLine(nil, 4)
		if imgui.Button('Х'..id_name..'button_12', imgui.ImVec2(18, 20)) then
			iptTmp.iptMir1 = nil
			tmp.iptMir2 = nil
		end
		imgui.Tooltip('Очистить')

		local txtChat = '/news '..esterscfg.events.mirror.tag..(tmp.iptMir2 and tmp.iptMir2..' = ?' or 'Тевирп = ?')
		imgui.SetCursorPos(imgui.ImVec2(8, imgui.GetCursorPosY() + 3))
		if imgui.Button(tmp.iptMir2 or 'Тевирп'..id_name..'button_16', imgui.ImVec2(imgui.GetWindowWidth() - 20, 20)) then
			sampSetChatInputEnabled(true)
			sampSetChatInputText(u8:decode(txtChat))
		end
		imgui.Tooltip('Крикабельно, вставит в чат:\n\n'..txtChat)

		imgui.SetCursorPosY(imgui.GetCursorPosY() + 6)
		imgui.Separator()
		imgui.SetCursorPosY(imgui.GetCursorPosY() + 4)

		imgui.MeNotepad('mirror')
	imgui.EndChild()
end
function imgui.ScrSettings() -- Настройки
	if imgui.Checkbox('Изменить размер окна'..id_name..'checkbox_1', cheBoxSize) then
		setup.cheBoxSize = cheBoxSize[0]
		saveFile('settings.cfg', setup)
	end
	if KeyEditor('menu', 'Открыть главное меню', imgui.ImVec2(280,25)) then
		saveKeysBind()
	end
	if KeyEditor('helpMenu', 'Вспомогательное меню', imgui.ImVec2(280,25)) then
		saveKeysBind()
	end
	if KeyEditor('catchAd', 'Редактор объявлений', imgui.ImVec2(280,25)) then
		saveKeysBind()
	end
	if KeyEditor('copyAd', 'Скопировать объявление', imgui.ImVec2(280,25)) then
		saveKeysBind()
	end
	if KeyEditor('fastMenu', 'Быстрое меню', imgui.ImVec2(280,25)) then
		saveKeysBind()
	end
	imgui.PushItemWidth(280)
	imgui.SliderInt(id_name..'slider_2', newsDelay, 1, 50, 'Задержка "/newsredak" ('..newsDelay[0] * 10 ..')')
	if not imgui.IsItemActive() and setup.newsDelay ~= newsDelay[0] then
		if newsDelay[0] < 1 or newsDelay[0] > 50 then
			newsDelay[0] = setup.newsDelay
			return
		end
		setup.newsDelay = newsDelay[0]
		saveFile('settings.cfg', setup)
	end
	imgui.Tooltip('Это дополнительная задержка, при\nфлуде командой. Если у вас пишет\n"Не Флуди!", индивидуально\nувеличите задержку')
end

-- Разделы в фаст меню
function imgui.FmInterviews()
	local refusals = {
		{'Назад', function ()
			tmp.fmRef = nil
		end},
		{'Законка', function ()
			sampSendChat(u8:decode(tmp.targetPlayer.nick:gsub('_', ' ')..', извините, но Вы незаконопослушный гражданин. Приходите когда исправитесь.'))
			wait(1000)
			sampSendChat(u8:decode('/b Чтобы работать в гос. структуре, нужно иметь минимум 35+ законки'))
		end},
		{'Варн', function ()
			sampSendChat(u8:decode(tmp.targetPlayer.nick:gsub('_', ' ')..', извините, но Вы находитесь в ЧС штата, поэтому не можете у нас работать.'))
			wait(1000)
			sampSendChat(u8:decode('/b У Вас есть WARN на аккаунте.'))
		end},
		{'НРП ник', function ()
			sampSendChat(u8:decode(tmp.targetPlayer.nick:gsub('_', ' ')..', извините, но у Вас в паспорте опечатка. Исправьте и приходите.'))
			wait(1000)
			sampSendChat(u8:decode('/b У Вас нонРП ник. Его можно исправить в /mm - 1 - 12'))
		end},
		{'Другая ОРГ', function ()
			sampSendChat(u8:decode(tmp.targetPlayer.nick:gsub('_', ' ')..', извините, но Вы работаете в другой организации.'))
			wait(1000)
			sampSendChat(u8:decode('Чтобы устроиться к нам, увольтесь и приходите вновь.'))
		end},
		{'Нет 3 ур', function ()
			sampSendChat(u8:decode(tmp.targetPlayer.nick:gsub('_', ' ')..', извините но чтобы работать в гос. организации нужно иметь 3-х летнюю прописку в штате.'))
			wait(1000)
			sampSendChat(u8:decode('/b Вам нужно 3+ уровень персонажа.'))
		end},
		{'В ЧС', function ()
			sampSendChat(u8:decode(tmp.targetPlayer.nick:gsub('_', ' ')..', извините, но Вы находитесь в черном списке нашей организации.'))
		end},
		{'Нарко', function ()
			sampSendChat(u8:decode(tmp.targetPlayer.nick:gsub('_', ' ')..', извините, но Вы нам не подходите. Вы наркозависимы.'))
		end},
		{'Мед.карта', function ()
			sampSendChat(u8:decode(tmp.targetPlayer.nick:gsub('_', ' ')..', извините, но для того чтобы устроить к нам нужно обновить мед. карту.'))
			wait(1000)
			sampSendChat(u8:decode('Обновить её можно в любой больницы штата.'))
		end}
	}
	local buttons = {
		{'Приветствие', function ()
			sampSendChat(u8:decode('Здравствуйте, вы пришли на собеседование?'))
		end},
		{'Запрос документов', function ()
			sampSendChat(u8:decode('Хорошо, покажите ваши документы. А именно паспорт, лицензии и мед. карту.'))
			wait(1000)
			local myId = select(2,sampGetPlayerIdByCharHandle(PLAYER_PED))
			sampSendChat(u8:decode(string.format('/b /showpass %s | /showlic %s | /showmc %s', myId, myId, myId)))
		end},
		{'Проверка документов', function ()
			if sampIsDialogActive() then 
				if tmp.lastDialog.title == '{BFBBBA}Мед. карта' then
					sampSendChat(u8:decode('/me взял у человека напротив мед. карту, затем внимательно изучил её'))
					wait(1000)
					if tmp.lastDialog.text:match('{FFFFFF}Имя: '..tmp.targetPlayer.nick) then
						local narko = tonumber(tmp.lastDialog.text:match('{CEAD2A}Наркозависимость: ([%d%.]+){FFFFFF}'))
						if narko <= 3 then -- 3 Заменить на переменную настройки
							sampSendChat(u8:decode('/do Мед. карту человека впорядке.'))
							wait(1000)
							sampSendChat(u8:decode('/me вернул мед. карту человеку напротив'))
						else
							for f=1, #refusals do
								if refusals[f][1] == 'Нарко' then refusals[f][2]() break end
							end
						end
					else
						sampAddChatMessage(u8:decode(tag..'Мед. книжка другова человека!'), -1)
					end		
				elseif tmp.lastDialog.title == '{BFBBBA}Паспорт' then
					sampSendChat(u8:decode('/me взял у человека напротив паспорт, затем внимательно изучил его'))
					wait(1000)
					if tmp.lastDialog.text:match('{FFFFFF}{FFFFFF}Имя: {FFD700}'..tmp.targetPlayer.nick) then
						if tmp.targetPlayer.score >= 3 then
							if tmp.lastDialog.text:match('{FF6200}Лечился в Психиатрической больнице: %d+ .- %(Необходимо обновить мед%. карту%)') then
								for f=1, #refusals do
									if refusals[f][1] == 'Мед.карта' then refusals[f][2]() break end
								end
							else
								if tonumber(tmp.lastDialog.text:match('{FFFFFF}Законопослушность: {FFD700}(%d+)/100')) < 35 then
									for f=1, #refusals do
										if refusals[f][1] == 'Законка' then refusals[f][2]() break end
									end
								else
									sampSendChat(u8:decode('/do В паспорте нет опечаток.'))
									wait(1000)
									sampSendChat(u8:decode('/me вернул человеку напротив паспорт'))
								end
							end
						else
							for f=1, #refusals do
								if refusals[f][1] == 'Нет 3 ур' then refusals[f][2]() break end
							end
						end
					else
						sampAddChatMessage(u8:decode(tag..'Паспорт принадлежит другому человеку!'), -1)
					end
				elseif tmp.lastDialog.title == '{BFBBBA}Лицензии' then
					sampSendChat(u8:decode('/me взял у человека напротив лицензии, затем внимательно изучил их'))
					wait(1000)
					if tmp.lastDialog.text:match('{FFFFFF}Лицензия на авто: 		{FF6347}Нет {cccccc}%(.-%)') then
						sampSendChat(u8:decode('/do Необходимой лицензии у человека нет.'))
						wait(1000)
						sampSendChat(u8:decode('Вам необходимо получить лицензию на вождение транспортом. Это можно сделать в Центре Лицензирования г. Сан-Фиерро.'))
					else
						sampSendChat(u8:decode('/do Необходимая лицензия имеется.'))
						wait(1000)
						sampSendChat(u8:decode('/me вернул человеку напротив лицензии'))
					end
				elseif tmp.lastDialog.title == '{BFBBBA}{73B461}Активные предложения' and tmp.lastDialog.style == 5 then
					local numLine = -1
					for line in tmp.lastDialog.text:gmatch('[^\n]+') do
						if line:match('{ffffff} Предлагает посмотреть .-%.%.\t'..tmp.targetPlayer.nick) then
							tmp.fmActi = true; sampSendDialogResponse(tmp.lastDialog.id, 1, numLine, nil); break
						end
						numLine = numLine + 1
					end
					if not tmp.fmActi then
						sampAddChatMessage(u8:decode(tag..'Данный человек не предлогал свои документы!'), -1)
					end
				end
			else
				tmp.fmActi, tmp.fmActiT = true, os.clock()
				sampSendChat(u8:decode('/offer'))
				while tmp.fmActi and (os.clock() - tmp.fmActiT < 3) do
					if tmp.lastDialog and tmp.lastDialog.title == '{BFBBBA}{73B461}Активные предложения' and tmp.lastDialog.style == 5 then
						local numLine = -1
						for line in tmp.lastDialog.text:gmatch('[^\n]+') do
							if line:match('{ffffff} Предлагает посмотреть .-%.%.\t'..tmp.targetPlayer.nick) then
								tmp.fmActi = true; sampSendDialogResponse(tmp.lastDialog.id, 1, numLine, nil); break
							end
							numLine = numLine + 1
						end
						if not tmp.fmActi then
							sampSendDialogResponse(tmp.lastDialog.id, 0, nil, nil)
							sampAddChatMessage(u8:decode(tag..'Данный человек не предлогал свои документы!'), -1)
						end
						break
					end
					wait(100)
				end
			end
		end, 'Автоматическая проверка документов'},
		{'Вопрос №1', function ()
			sampSendChat(u8:decode('Хорошо... Что находится у меня над головой?'))
		end, 'В чат: Хорошо... Что находится у меня над головой?'},
		{'Вопрос №2', function ()
			sampSendChat(u8:decode('Прекрасно, расскажите что-нибудь о себе?'))
		end, 'В чат: Прекрасно, расскажите что-нибудь о себе?'},
		{'Вопрос №3', function ()
			sampSendChat(u8:decode('Почему вы выбрали именно наш радиоцентр?'))
		end, 'В чат: Почему вы выбрали именно наш радиоцентр?'},
		{'Вы подходите', function ()
			sampSendChat(u8:decode('Поздравляю! Вы нам подходите! Раздевалка находится на 2 этаже.'))
			wait(1000)
			sampSendChat(u8:decode('/invite '..tmp.targetPlayer.id))
		end, 'В чат: Поздравляю! Вы нам подходите!\nРаздевалка находится на 2 этаже.'},
		{'Отказ', function ()
			tmp.fmRef = true
		end}
	}
	local menu = not tmp.fmRef and buttons or refusals
	for i=1, #menu do
		if imgui.Button(menu[i][1]..id_name..'button_FM_'..i, imgui.ImVec2(270, 27)) then
			if tmp.rolePlay then return end tmp.rolePlay = true
			lua_thread.create(function ()
				if tmp.fmRef then tmp.fmRef= nil end
				menu[i][2]()
				tmp.rolePlay = false
			end)
		end
		if menu[i][3] then imgui.Tooltip(menu[i][3]) end
	end
end

-- +++++++++++++++++++++++ Рабочие функции ++++++++++++++++++++++++++++ --
function imgui.Tooltip(text)
	if imgui.IsItemHovered() then
		imgui.BeginTooltip()
		imgui.PushFont(s4)
		imgui.Text(text)
		imgui.PopFont()
		imgui.EndTooltip()
	end
end
function imgui.TextStart(text)
	imgui.RenderText(tostring(text))
end
function imgui.TextCenter(text)
	text = tostring(text)
	imgui.SetCursorPosX(imgui.GetWindowWidth() / 2  - imgui.CalcTextSize(tostring(text:gsub('{%x%x%x%x%x%x%x?%x?}', ''):gsub('{STANDART}', ''))).x / 2 - 2)
	imgui.RenderText(text)
end
function imgui.TextEnd(text)
	text = tostring(text)
	imgui.SetCursorPosX(imgui.GetWindowWidth() - imgui.CalcTextSize(tostring(text:gsub('{%x%x%x%x%x%x%x?%x?}', ''):gsub('{STANDART}', ''))).x - 8)
	imgui.RenderText(text)
end
function imgui.isPlaceHovered(a, b)
	local m = imgui.GetMousePos()
	if m.x >= a.x and m.y >= a.y then
		if m.x <= b.x and m.y <= b.y then
			return true
		end
	end
	return false
end
function imgui.bringVec4To(from, to, start_time, duration)
    local timer = os.clock() - start_time
    if timer >= 0.00 and timer <= duration then
        local count = timer / (duration / 100)
        return imgui.ImVec4(
            from.x + (count * (to.x - from.x) / 100),
            from.y + (count * (to.y - from.y) / 100),
            from.z + (count * (to.z - from.z) / 100),
            from.w + (count * (to.w - from.w) / 100)
        ), true
    end
    return (timer > duration) and to or from, false
end
function imgui.bringFloatTo(from, to, start_time, duration)
    local timer = os.clock() - start_time
    if timer >= 0.00 and timer <= duration then
        local count = timer / (duration / 100)
        return from + (count * (to - from) / 100), true
    end
    return (timer > duration) and to or from, false
end
function imgui.set_alpha(color, alpha)
	alpha = alpha and imgui.limit(alpha, 0.0, 1.0) or 1.0
	return imgui.ImVec4(color.x, color.y, color.z, alpha)
end
function imgui.limit(v, min, max)
	min = min or 0.0
	max = max or 1.0
	return v < min and min or (v > max and max or v)
end

function updateFile(filename, default)
	local cfg = loadFile(filename, default)
	if default.reset ~= cfg.reset then 
		cfg = table.recuiteral(default, cfg)
		cfg.reset = default.reset
		saveFile(filename, cfg)
	end
	return cfg
end
function saveFile(filename, tbl)
	local direct = getWorkingDirectory() .. '\\config\\News Helper\\' .. filename
	if not pcall(table.save, tbl, direct) then
		print(u8:decode('{CC0F00}ERROR:{999999}Ошибка сохранения файла: {FFAA00}'..filename))
		print(u8:decode('{CAAF00}!!! {999999}Это внутреннея ошибка скрипта, сообщите разработчику {CAAF00}!!!'))
	end
end
function loadFile(filename, option)
	local direct = getWorkingDirectory() .. '\\config\\News Helper\\' .. filename
	local tTable = option
	if pcall(table.read, direct) then local st = table.read(direct) tTable = st or option else
		print(u8:decode('{CC0F00}ERROR:{999999}Ошибка подгрузки файла: {FFAA00}'..filename))
		print(u8:decode('{CAAF00}!!! {999999}Были загружены стандартные значения, для сохранения..'))
		print(u8:decode('{999999}..своих старых настроек рекомендуется сделать бэкап файла {CAAF00}!!!'))
	end
	return tTable
end
function table.save(tbl, fn)
	local f, err = io.open(fn, "w")
	if not f then
		return nil, err
	end
	tmp.tag = ''
	f:write(table.tostring(tbl, true))
	f:close()
	tmp.tag = nil
	return true
end
function table.read(fn)
	local f, err = io.open(fn, "r")
	if not f then
		return nil, err
	end
	local tbl = assert(loadstring("return " .. f:read("*a")))
	f:close()
	return tbl()
end
function table.key_to_str(k)
	if "string" == type(k) and string.match(k, "^[_%a][_%a%d]*$") then
		return k
	end
	return "[" .. table.val_to_str(k) .. "]"
end
function table.val_to_str(v, st)
	if "string" == type(v) then
		v = string.gsub(v, "\\", "\\\\")
		v = string.gsub(v, "\n", "\\n")
		return "'" .. string.gsub(v,"'", "\\'") .. "'"
	end
	if tmp.tag then tmp.tag = tmp.tag .. '\t' end
		local tt = "table" == type(v) and table.tostring(v) or tostring(v)
	if tmp.tag then tmp.tag = '' end
	return tt
end
function table.tostring(tbl) -- Потом доделать
	local result, done = {}, {}
	for k, v in ipairs(tbl) do
		table.insert(result, tmp.tag..'\t'..table.val_to_str(v))
		done[k] = true
	end
	for k, v in pairs(tbl) do
		if not done[k] then
			table.insert(result, tmp.tag..'\t'..table.key_to_str(k) .. " = " .. table.val_to_str(v))
		end
	end
	return tmp.tag:gsub('%s', '', 1).."{\n" .. table.concat(result, ",\n") .. "\n"..tmp.tag.."}"
end
function table.recuiteral(out, inA)
	if type(out) ~= 'table' or type(inA) ~= 'table' then return {} end
	local k, v = next(out)
	while k do
		if not inA[k] and type(k) == 'string' then
			inA[k] = v
		elseif type(v) == 'table' and type(inA[k]) == 'table' then
			inA[k] = table.recuiteral(v, inA[k]) 
		end
		k, v = next(out, k)
	end
	return inA
end

function utf8len(s)
	local s = tostring(s)
	local pos = 1
	local bytes = s:len()
	local len = 0
	while pos <= bytes do
		len = len + 1
		pos = pos + utf8charbytes(s, pos)
	end
	return len
end
function utf8charbytes(s, i)
    local i = i or 1
    local c = string.byte(s, i)

    if c > 0 and c <= 127 then
        return 1
    elseif c >= 194 and c <= 223 then
        local c2 = string.byte(s, i + 1)
        return 2
    elseif c >= 224 and c <= 239 then
        local c2 = s:byte(i + 1)
        local c3 = s:byte(i + 2)
        return 3
    elseif c >= 240 and c <= 244 then
        local c2 = s:byte(i + 1)
        local c3 = s:byte(i + 2)
        local c4 = s:byte(i + 3)
        return 4
    end
end
function utf8sub(s, i, j)
    local j = j or -1
    if i == nil then return "" end

    local pos = 1
    local bytes = string.len(s)
    local len = 0

    local l = (i >= 0 and j >= 0) or utf8len(s)
    local startChar = (i >= 0) and i or l + i + 1
    local endChar = (j >= 0) and j or l + j + 1

    if startChar > endChar then
        return ""
    end

    local startByte, endByte = 1, bytes

    while pos <= bytes do
        len = len + 1
        if len == startChar then
            startByte = pos
        end

        pos = pos + utf8charbytes(s, pos)
        if len == endChar then
            endByte = pos - 1
            break
        end
    end

    return string.sub(s, startByte, endByte)
end
function utf8replace(s, mapping)
    local pos = 1
    local bytes = string.len(s)
    local charbytes
    local newstr = ""

    while pos <= bytes do
        charbytes = utf8charbytes(s, pos)
        local c = string.sub(s, pos, pos + charbytes - 1)
        newstr = newstr .. (mapping[c] or c)
        pos = pos + charbytes
    end

    return newstr
end
function string.nlower(s)
    local s, res = string.lower(u8:decode(s)), {}
    for i = 1, #s do
        local ch = s:sub(i, i)
        res[i] = ul_rus[ch] or ch
    end
    return u8:encode(table.concat(res))
end
function string.nupper(s)
    local s, res = string.upper(u8:decode(s)), {}
    for i=1, #s do
        local ch = s:sub(i, i)
        res[i] = un_rus[ch] or ch
    end
    return u8:encode(table.concat(res))
end
function string.hexsub(str)
	return str:gsub('{%x%x%x%x%x%x%}', ''):gsub('{%x%x%x%x%x%x%x%x}', ''):gsub('{STANDART}', '')
end
function string.regular(rgx)
	local str = ''
	for i=1, #rgx do
		local sign = rgx:sub(i, i)
		if sign:match('%p') then
			str = str..string.char(37, sign:byte())
		else 
			str = str..string.char(sign:byte())
		end
	end
	return str
end
function urlEncode(str)
	local str = string.gsub(str, "\\", "\\")
	local str = string.gsub(str, "([^%w])", function (str) return string.format("%%%02X", string.byte(str)) end)
	return str
end
function httpBuild(query)
	local buff=""
	for k, v in pairs(query) do
		buff = buff.. string.format("%s=%s&", k, urlEncode(v))
	end
	local buff = string.reverse(string.gsub(string.reverse(buff), "&", "", 1))
	return buff
end


function getDownKeys()
    local t = {}
    for index, KEYID in ipairs(hotkey.LargeKeys) do
        if isKeyDown(KEYID) then
            table.insert(t, KEYID)
        end
    end
    return t
end
function GetKeysText(bind)
    local t = {}
    if hotkey.List[bind] then
        for k, v in ipairs(hotkey.List[bind].keys) do
            table.insert(t, vk.id_to_name(v):gsub('Numpad ', 'Num'):gsub('Arrow ', '') or 'UNK')
        end
    end
    return table.concat(t, ' + ')
end
function RegisterCallback(name, keys, callback)
    if hotkey.List[name] == nil then
        hotkey.List[name] = {
            keys = keys,
            callback = callback
        }
        return true else return false
    end
end
function KeyEditor(bindname, text, size)
    if hotkey.List[bindname] then
        local keystext = #hotkey.List[bindname].keys == 0 and hotkey.Text.no_key or GetKeysText(bindname)
        if hotkey.EditKey ~= nil then
            if hotkey.EditKey == bindname then
                keystext = hotkey.Text.wait_for_key
            end
        end 
        if imgui.Button((text ~= nil and text..': ' or '')..keystext..'##hotkey_EDITOR:'..bindname, size) then
            hotkey.Edit.backup = hotkey.List[bindname].keys
            hotkey.List[bindname].keys = {}
            hotkey.EditKey = bindname
        end
        if hotkey.Ret.name ~= nil then
            if hotkey.Ret.name == bindname then
                hotkey.Ret.name = nil
                return hotkey.Ret.data
			end
        end
    else
        imgui.Button('Bind "'..tostring(bindname)..'" not found##hotkey_EDITOR:BINDNAMENOTFOUND', size)
    end
	imgui.Tooltip('Можно использовать любую клавишу или\nкоомбинацию клавишь. (Shift - выключен)\n\nAlt/Ctrl/Space/Enter + Любая клавиша.\nBackspace - Удалить сохранёный бинд.\nESC - Отменить изминение')
end
function saveKeysBind()
	for k, _ in pairs(setup.keys) do
		if hotkey.List[k] then
			setup.keys[k] = hotkey.List[k].keys
		end
	end
	saveFile('settings.cfg', setup)
end
function clearButtons()
	for k, _ in pairs(hotkey.List) do
		local var = k:match('bindCfg_([%d]+)')
		if var then
			hotkey.List['bindCfg_'..var] = nil
		end
	end
end

function setDialogCursorPos(pos)
    local m_pEditbox = memory.getuint32(sampGetDialogInfoPtr() + 0x24, true)
    memory.setuint8(m_pEditbox + 0x119, pos, true)
    memory.setuint8(m_pEditbox + 0x11E, pos, true)
end
function setChatCursorPos(pos)
    local pEditBox = memory.getuint32(sampGetInputInfoPtr() + 0x08, true)
    memory.setuint8(pEditBox + 0x119, pos, true)
    memory.setuint8(pEditBox + 0x11E, pos, true)
end
function getDialogCursorPos()
    local m_pEditbox = memory.getuint32(sampGetDialogInfoPtr() + 0x24, true)
    return memory.getuint8(m_pEditbox + 0x119, true)
end
function getChatCursorPos()
    local pEditBox = memory.getuint32(sampGetInputInfoPtr() + 0x08, true)
    return memory.getuint8(pEditBox + 0x119, true)
end

function pushArrS(arr)
	local arr = decodeJson(encodeJson(arr)) or {}
	for i, name in ipairs(nHelpEsterSet[1]) do
		table.insert(arr, {name, esterscfg.settings[name], nHelpEsterSet[3][i], 'В настройках отсутствует {fead00}'..nHelpEsterSet[2][i]..'{C0C0C0} что-бы использовать в эфире!', nHelpEsterSet[4][i]})
	end
	return arr
end
function regexTag(str, tagsArr)
	if not str then return 'err' end
	for _, t in ipairs(pushArrS(tagsArr)) do
		str = str:gsub('{'..t[1]..'}', t[2] ~= '' and t[2] or t[3])
	end
	return str
end
function findTag(arr, find)
	for _, str in ipairs(arr) do
		if str:find('{'..find..'}') then
			return true
		end
	end
	return false
end

function openMenu()
	if not isPauseMenuActive() then
		rMain[0] = not rMain[0]
		rSW[0] = false
	end
end
function resetIO()
    for i = 0, 511 do
        imgui.GetIO().KeysDown[i] = false
    end
    for i = 0, 4 do
        imgui.GetIO().MouseDown[i] = false
    end
    imgui.GetIO().KeyCtrl = false
    imgui.GetIO().KeyShift = false
    imgui.GetIO().KeyAlt = false
    imgui.GetIO().KeySuper = false
end

addEventHandler('onWindowMessage', function(msg, key) -- Доделать
	if isSampAvailable() then
		if (msg == 0x0100 or msg == 260) and not sampIsChatInputActive() then --and not sampIsDialogActive()
			if hotkey.EditKey == nil then
				if (hotkey.no_flood and key ~= hotkey.lastkey) or (not hotkey.no_flood) then
					hotkey.lastkey = key
					for name, data in pairs(hotkey.List) do
						keys = data.keys
						if (#keys == 1 and key == keys[1]) or (#keys == 2 and isKeyDown(keys[1]) and key == keys[2]) then
							if data.callback then data.callback(name) end
						end
					end
				end
				if hotkey.EditKey ~= nil then
					if #hotkey.List[hotkey.EditKey] < 2 then
						table.insert(hotkey.List[hotkey.EditKey], key)
					end
				end
			else
				if key == vk.VK_ESCAPE then
					hotkey.List[hotkey.EditKey].keys = hotkey.Edit.backup
					hotkey.EditKey = nil
					consumeWindowMessage(true, false)
					return
				elseif key == vk.VK_BACK then
					hotkey.List[hotkey.EditKey].keys = {}
					hotkey.EditKey = nil
					saveKeysBind()
					clearButtons()
				end
			end
		elseif (msg == 0x0101 or msg == 261) and not sampIsChatInputActive() then --and not sampIsDialogActive()
			if hotkey.EditKey ~= nil then
				if key == vk.VK_BACK then
					hotkey.List[hotkey.EditKey].keys = {}
					hotkey.EditKey = nil
				else
					local PressKey = getDownKeys()
					local LargeKey = PressKey[#PressKey]
					if LargeKey == 16 then return end -- Убираем shift
					hotkey.List[hotkey.EditKey].keys = {#PressKey > 0 and PressKey[#PressKey] or key, #PressKey > 0 and key or nil}
					if hotkey.List[hotkey.EditKey].keys[1] == hotkey.List[hotkey.EditKey].keys[2] then
						hotkey.List[hotkey.EditKey].keys[2] = nil
					end
					hotkey.Ret.name = hotkey.EditKey
					hotkey.Ret.data = hotkey.List[hotkey.EditKey].keys
					hotkey.EditKey = nil
				end
			end
		end

		if msg == 0x100 --[[or msg == 0x101]] then -- msg == 0x100 or msg == 0x101
			if (key == vk.VK_TAB and (rMain[0] or rHelp[0] or rSW[0])) and not isPauseMenuActive() then
				-- Будет работать как скрыть/раскрыть. Запоминая окна.
			end
			if (key == vk.VK_ESCAPE and (rMain[0] or rHelp[0] or rSW[0])) and not isPauseMenuActive() then
				consumeWindowMessage(true, false)
				if msg == 0x100 then
					if rSW[0] then rSW[0] = false; rMain[0] = true
					else rMain[0] = false; rHelp[0] = false; resetIO() end
				end
			end
		end
	end

end)

function Style()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
  
    style.WindowRounding = 5
    style.FrameRounding = 3
    style.ScrollbarRounding = 3
    style.GrabRounding = 1
    -- style.ChildRounding = 3

    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    --style.WindowPadding = imgui.ImVec2(20, 20)
    style.WindowBorderSize = 1
	style.FrameBorderSize = 1
    -- style.FramePadding = imgui.ImVec2(5, 5)
    -- style.ItemSpacing = imgui.ImVec2(12, 8)
    -- style.ItemInnerSpacing = imgui.ImVec2(8, 6)
    -- style.IndentSpacing = 25
    style.ScrollbarSize = 17
    -- style.GrabMinSize = 5

    colors[clr.Text] = ImVec4(0.86, 0.93, 0.89, 0.78)
    colors[clr.TextDisabled] = ImVec4(0.36, 0.42, 0.47, 1)
    colors[clr.WindowBg] =  ImVec4(0.11, 0.15, 0.17, 1)
    --colors[clr.ChildBg] =  ImVec4(0.15, 0.18, 0.22, 1)
    colors[clr.PopupBg] = ImVec4(0.08, 0.08, 0.08, 0.94)
    colors[clr.FrameBg] = ImVec4(0.20, 0.25, 0.29, 1)
    colors[clr.FrameBgHovered] = ImVec4(0.12, 0.20, 0.28, 1)
    colors[clr.FrameBgActive] = ImVec4(0.09, 0.12, 0.14, 1)
	colors[clr.Tab] = ImVec4(0.26, 0.98, 0.85, 0.30)
	colors[clr.TabHovered] = ImVec4(0.26, 0.98, 0.85, 0.50)
	colors[clr.TabActive] = ImVec4(0.26, 0.98, 0.85, 0.50)
    colors[clr.TitleBg] = ImVec4(0.11, 0.15, 0.17, 1) -- 0.04, 0.04, 0.04, 1
    colors[clr.TitleBgCollapsed] = ImVec4(0.00, 0.00, 0.00, 0.51)
    colors[clr.TitleBgActive] = ImVec4(0.11, 0.15, 0.17, 1)
    colors[clr.MenuBarBg] = ImVec4(0.15, 0.18, 0.22, 1)
    colors[clr.ScrollbarBg] = ImVec4(0.02, 0.02, 0.02, 0.39)
    colors[clr.ScrollbarGrab] = ImVec4(0.26, 0.98, 0.85, 0.30)
    colors[clr.ScrollbarGrabHovered] = ImVec4(0.18, 0.22, 0.25, 1)
    colors[clr.ScrollbarGrabActive] = ImVec4(0.26, 0.98, 0.85, 0.50)
    colors[clr.CheckMark] = ImVec4(0.26, 0.98, 0.85, 1)
    colors[clr.SliderGrab] = ImVec4(0.23, 0.98, 0.84, 0.3)
    colors[clr.SliderGrabActive] = ImVec4(0.23, 0.98, 0.84, 0.7)
    colors[clr.Button] = ImVec4(0.26, 0.98, 0.85, 0.30)
    colors[clr.ButtonHovered] = ImVec4(0.26, 0.98, 0.85, 0.50)
    colors[clr.ButtonActive] = ImVec4(0.06, 0.98, 0.82, 0.50)
    colors[clr.Header] = ImVec4(0.26, 0.98, 0.85, 0.31)
    colors[clr.HeaderHovered] = ImVec4(0.26, 0.98, 0.85, 0.30)
    colors[clr.HeaderActive] = ImVec4(0.26, 0.98, 0.85, 0.60)
    colors[clr.ResizeGrip] = ImVec4(0.26, 0.59, 0.98, 0.25)
    colors[clr.ResizeGripHovered] = ImVec4(0.26, 0.59, 0.98, 0.67)
    colors[clr.ResizeGripActive] = ImVec4(0.06, 0.05, 0.07, 1)
    colors[clr.PlotLines] = ImVec4(0.61, 0.61, 0.61, 1)
    colors[clr.PlotLinesHovered] = ImVec4(1, 0.43, 0.35, 1)
    colors[clr.PlotHistogram] =  ImVec4(0.90, 0.70, 0.00, 1)
    colors[clr.PlotHistogramHovered] = ImVec4(1, 0.60, 0.00, 1)
    colors[clr.TextSelectedBg] = ImVec4(0.25, 1, 0.00, 0.43)
	colors[clr.Border] = ImVec4(0.30, 0.35, 0.39, 1)
end


-- ================== Объёмные переменные ======================== --
function loadVar()
	thUpd = {
		'https://'..thisScript().authors[1]..'.net/NewsVersion.json',
		['tr'] = false,
		['inf'] = '',
		{
			{['version'] = '0.1.12 alpha', {
				' - Исправлен баг, когда в эфире "Прятки" не работала ключевая фраза',
				' - Добавлено несколько новых эфиров:',
			   	'   Переводчик (есть возможность переводить свои слова)',
			   	'   Зеркало (есть возможность переворачивать свои слова)',
			   	'   Столицы (есть заготовки)',
				' - Теперь в меню редактирования эфиров, при переходе в режим "Проверки",',
				'   замененый текст тэгов будет также подсвечиваться зеленым',
				' - Изменен вид конфигов, теперь в них можно хоть что-то разобрать'
				}
			},{['version'] = '0.1.11.3 alpha', {
				' - Добавлена индивидуальная задержка для /newsredak,',
				'   теперь можно индивидуально настроить её для себя',
				' - Пофикшена вставка микрокоманд и биндов в диалоге',
				'   редактирования объявления, теперь текст вставляется,',
				'   туда где находится курсор.',
				' - Так же добавлены небольшие визуальные изминения'
				}
			},{['version'] = '0.1.11.2 alpha', {
				' - Добавлена визуализация тегов (в меню редактирования',
				'   эфиров) и более подробная информация о них',
				' - Фикс имен в эфирах, на вайсити теперь ники без серверов',
				' - Небольшие удобства, в эфирах где текст вставляется в чат, курсор',
				'   будет перемещаться в место, где нужно заполнить информацию',
				' - Добавлены ларцы в разное, исправлено некоторое описание',
				'   в меню помощи (Delete)',
				' - Откорректирована работа "Редактора объявлений", теперь',
				'   флуда не должно быть. (Можно зажимать клавишу)'
				}
			},{['version'] = '0.1.11 alpha', {
				' - Добавлена возможность создавать и редактировать',
				'   кнопочные - бинды. В разделе Редакция.',
				' - Исправленна баг с использованием регулярных символов',
				'   в разделе автозамены. Теперь можно использовать',
				'   точки, скобки, проценты и т.п. ("..", "%%", "[?")',
				' - Добавлен резервный сервер для обновления скрипта,',
				'   некоторые провайдеры из Украины блокировали мой',
				'   сервер, теперь вы сможете обновлятся без проблем.'
				}
			},{['version'] = '0.1.10 alpha', {
				' - Добавлены первые несколько эфиров и приколы к ним',
				--' - Очень много внутренних исправлений и доработак,',
				--'   добавленны callback обработчики для полей ввода',
				' - Теперь при добавлении новых кнопок или дополнительных',
				'   эфиров, у вас не будут сбрасываться ваши настройки',
				' - Далее будет добавлена заменяющее окно для диалога',
				'   редактирования обЪявлений, со своими фишками'
				}
			},{['version'] = '0.1.9.7 alpha', {
				' - Исправлен баг с падением FPS в разделе Редакция, объявления',
				' - Небольшие исправления и авто-стерание спец.символов в',
				'   меню помощи редакции (Delete)',
				' - Далее будет добавлены Эфиры и меню редактирования объявления'
				}
			},{['version'] = '0.1.9.3 alpha', {
				' - Исправлены очепятки'
				}
			},{['version'] = '0.1.9.1 alpha', {
				' - Исправлен баг, последний элемент в автозамене теперь сохнаряется',
				' - Поиск во вкладке с объявлениями, теперь закреплён',
				' - Некоторые маленькие обновления и справления',
				' - След. обновление 0.2.0, будет более маштабное..'
				}
			},{['version'] = '0.1.8 alpha', {
				' - В Быстрое меню было добавленно и доведено до ума "Собеседывание"',
				' - В скором времени оно полностью будет готово, и будет возможность',
				'   изменять некоторые параметры. (Т.к. на всех серверах свои правила)'
				}
			},{['version'] = '0.1.7.8 alpha', {
				' - Улучшено отображение некоторых меню при изменении разрешения',
				' - Добавлено пару меню для теста, у вас сбросятся настройки кнопок'
				}
			},{['version'] = '0.1.7.3 alpha', {
				' - Исправлено закрытие окна вместе с отменой настроек клавиши',
				' - Добавлен поиск в список отредактированных объявлений'
				}
			},{['version'] = '0.1.7.2 alpha', {
				' - Исправлен критический баг, с крашем скрипта при входе',
				' - Исправлены нескольк биндов в меню помощи'
				}
			},{['version'] = '0.1.7.1 alpha', {
				' - Исправлены бинды в меню помощи',
				' - Исправленно блокирование кнопок в самой игре'
				}
			},{['version'] = '0.1.7 alpha', {
				' - Переделаны стандартное бинды в меню помощи "DELETE"',
				' - Добавленно перемещение курсора(insert) к первому,',
				'   символу * или "", если те присутствуют в тексте бинда',
				' - Добавлено корректная вставка бинд-сокращений,',
				'   теперь курсор(insert) ставится после микро-бинда',
				' - Добавлена история обновлений',
				' - Фикс сохранения спец.символов с файлами настроек',
				' - Добавлена возможность настраивать кнопки. Система',
				'   в тестовом варианте, если будут ошибки\\проблемы, пишите!',
				' - Несколько маленьких ошибок в коде'
				}
			},{['version'] = '0.1.6.2 alpha', {
				' - Заблокированна кнопка F3 когда вы поймали объявление',
				' - Переделанна система редактирования сохраннёных объявлений',
				' - Оптимизирован код в диалогах',
				' - Добавлена сокращенная команда',
				}
			}
		}
	}
	settingsSCR = {
		['reset'] = 'tet',
		['newsDelay'] = 13,
		['cheBoxSize'] = false,
		['thUpdDesc'] = nil,
		['keys'] = {
			['menu'] = {},
			['helpMenu'] = {vk.VK_DELETE},
			['catchAd'] = {vk.VK_F3},
			['copyAd'] = {vk.VK_DOWN},
			['fastMenu'] = {}
		}
	}
	newsHelpBind = {
		{'Покупка домов',
			{'Куплю дом в ЛС', 'Куплю дом в г. Лос-Сантос. Бюджет: '},
			{'Куплю дом в СФ', 'Куплю дом в г. Сан-Фиерро. Бюджет: '},
			{'Куплю дом в ЛВ', 'Куплю дом в г. Лас-Вентурас. Бюджет: '},
			{'Куплю дом в гетто', 'Куплю дом в опасном районе. Бюджет: '},
			{'Куплю дом в деревне', 'Куплю дом в деревне *. Бюджет: '},
			{'Куплю дом в ЛС(Г)', 'Куплю дом в г. Лос-Сантос с гаражом на * мест. Бюджет: '},
			{'Куплю дом в СФ(Г)', 'Куплю дом в г. Сан-Фиерро с гаражом на * мест. Бюджет: '},
			{'Куплю дом в ЛВ(Г)', 'Куплю дом в г. Лас-Вентурас с гаражом на * мест. Бюджет: '},
			{'Куплю дом в деревне(Г)', 'Куплю дом в деревне * с гаражом на * мест. Бюджет: '},
			{'Куплю дом в гетто(Г)', 'Куплю дом в опасном районе с гаражом на * мест. Бюджет: '},
			{'Куплю дом в ЛС(П)', 'Куплю дом в г. Лос-Сантос с подвалом. Бюджет: '},
			{'Куплю дом в СФ(П)', 'Куплю дом в г. Сан-Фиерро с подвалом. Бюджет: '},
			{'Куплю дом в ЛВ(П)', 'Куплю дом в г. Лас-Вентурас с подвалом. Бюджет: '},
			{'Куплю дом в деревне(П)', 'Куплю дом в деревне * с подвалом. Бюджет: '},
			{'Куплю дом в гетто(П)', 'Куплю дом в опасном районе с подвалом. Бюджет: '},
			{'Куплю дом в ЛС(Г+П)', 'Куплю дом в г. Лос-Сантос с гаражом и подвалом. Бюджет: '},
			{'Куплю дом в СФ(Г+П)', 'Куплю дом в г. Сан-Фиерро с гаражом и подвалом. Бюджет: '},
			{'Куплю дом в ЛВ(Г+П)', 'Куплю дом в г. Лас-Вентурас с гаражом и подвалом. Бюджет: '},
			{'Куплю дом в деревне(Г+П)', 'Куплю дом в деревне * с гаражом и подвалом. Бюджет: '},
			{'Куплю дом в гетто(Г+П)', 'Куплю дом в опасном районе с гаражом и подвалом. Бюджет: '},
			{'Куплю дом в любой ТШ', 'Куплю дом в любой точке штата. Бюджет: '},
			{'Куплю дом №', 'Куплю дом №*. Бюджет: '}
		},{'Продажа домов',
			{'Продам дом в ЛС', 'Продам дом в г. Лос-Сантос. Цена: '},
			{'Продам дом в СФ', 'Продам дом в г. Сан-Фиерро. Цена: '},
			{'Продам дом в ЛВ', 'Продам дом в г. Лас-Вентурас. Цена: '},
			{'Продам дом в Гетто', 'Продам дом в опасном районе. Цена: '},
			{'Продам дом в ЛС', 'Продам дом в деревне *. Цена: '},
			{'Продам дом в ЛС(Г)', 'Продам дом в г. Лос-Сантос с гаражом на * мест. Цена: '},
			{'Продам дом в СФ(Г)', 'Продам дом в г. Сан-Фиерро с гаражом на * мест. Цена: '},
			{'Продам дом в ЛВ(Г)', 'Продам дом в г. Лас-Вентурас с гаражом на * мест. Цена: '},
			{'Продам дом в деревне(Г)', 'Продам дом в деревне * с гаражом на * мест. Цена: '},
			{'Продам дом в Гетто (Г)', 'Продам дом в опасном районе с гаражом на * мест. Цена: '},
			{'Продам дом в ЛС(П)', 'Продам дом в г. Лос-Сантос с подвалом. Цена: '},
			{'Продам дом в СФ(П)', 'Продам дом в г. Сан-Фиерро с подвалом. Цена: '},
			{'Продам дом в ЛВ(П)', 'Продам дом в г. Лас-Вентурас с подвалом. Цена: '},
			{'Продам дом в деревне(П)', 'Продам дом в деревне * с подвалом. Цена: '},
			{'Продам дом в Гетто (П)', 'Продам дом в опасном районе с подвалом. Цена: '},
			{'Продам дом в ЛС(Г+П)', 'Продам дом в г. Лос-Сантос с гаражом и подвалом. Цена: '},
			{'Продам дом в СФ(Г+П)', 'Продам дом в г. Сан-Фиерро с гаражом и подвалом. Цена: '},
			{'Продам дом в ЛВ(Г+П)', 'Продам дом в г. Лас-Вентурас с гаражом и подвалом. Цена: '},
			{'Продам дом в деревне(Г+П)', 'Продам дом в деревне * с гаражом и подвалом. Цена: '},
			{'Продам дом в Гетто (Г+П)', 'Продам дом в опасном районе с гаражом и подвалом. Цена: '},
			{'Продам дом №', 'Продам дом №*. Цена: '}
		},{'Покупка/продажа транспорта',
			{'Продам а/м','Продам автомобиль "". Цена: '},
			{'Куплю а/м','Куплю автомобиль "". Бюджет: '},
			{'Куплю а/м любой модели','Куплю автомобиль любой модели. Бюджет: '},
			{'Продам м/т','Продам мотоцикл "". Цена: '},
			{'Куплю м/т','Куплю мотоцикл "". Бюджет: '},
			{'Куплю м/т любой модели','Куплю мотоцикл любой модели. Бюджет: '},
			{'Продам лодку', 'Продам лодку "". Цена: '},
			{'Куплю лодку', 'Куплю лодку "". Бюджет: '},
			{'Куплю лодку любой модели', 'Куплю лодку любой модели. Бюджет: '},
			{'Продам самолет', 'Продам самолет "". Цена: '},
			{'Куплю самолет', 'Куплю самолет "". Бюджет: '},
			{'Куплю самолет любой модели', 'Куплю самолет любой модели. Бюджет: '},
			{'Продам вертолет', 'Продам вертолет "". Цена: '},
			{'Куплю вертолет', 'Куплю вертолет "". Бюджет: '},
			{'Куплю вертолет любой модели', 'Куплю вертолет любой модели. Бюджет: '},
			{'Продам фуру', 'Продам фуру дальнобойщика "". Цена: '},
			{'Куплю фуру', 'Куплю фуру дальнобойщика "". Бюджет: '},
			{'Куплю фуру любой модели', 'Куплю фуру дальнобойщика любой модели. Бюджет: '}
		},{'Продажа/покупка бизнесов',
			{'Продам бизнес в ЛС','Продам бизнес * в г. Лос-Сантос. Цена: '},
			{'Куплю бизнес в ЛС','Куплю бизнес * в г. Лос-Сантос. Бюджет: '},
			{'Куплю бизнес','Куплю бизнес в любой точке штата. Бюджет: '},
			{'Продам бизнес в СФ','Продам бизнес * в г. Сан-Фиерро. Цена: '},
			{'Куплю бизнес в СФ','Куплю бизнес в г. Сан-Фиерро. Бюджет: '},
			{'Продам бизнес','Продам бизнес * №* . Цена:'},
			{'Продам бизнес в ЛВ','Продам бизнес * в г Лас-Вентурас. Цена: '},
			{'Куплю бизнес в ЛВ','Куплю бизнес в г. Лас-Вентурас. Бюджет: '},
			{'Продам бизнес в ФК','Продам бизнес * в д. Форт-Карсон. Цена: '},
			{'Куплю бизнес в ФК','Куплю бизнес в д. Форт-Карсон. Бюджет: '},
		},{'Покупка/продажа аксессуаров/одежды',
			{'Куплю а/с','Куплю а/с "". Бюджет: '},
			{'Продам а/с','Продам а/с "". Цена: '},
			{'Куплю а/с с заточкой','Куплю а/с "" с гравировкой (*). Бюджет: '},
			{'Продам а/с с заточкой','Продам а/с "" с гравировкой (*). Цена: '},
			{'Куплю одежду любого типа','Куплю одежду с любой биркой. Бюджет: '},
			{'Куплю одежду пошива','Куплю одежду с биркой "". Бюджет: '},
			{'Продам одежду пошива','Продам одежду с биркой "". Цена: '}
		},{'Реклама бизнесов',
			{'Работает бар','Работает бар №*, у нас самая вкусная еда и напитки! Приезжайте'},
			{'Работает закусочная','Работает закусочная №*, у нас самые дешевые цены во всем штате'},
			{'Работает отель','Работает отель №*, у нас самое дешевое заселение! Приезжайте'},
			{'Работает 24/7','Работает магазин 24/7 №*, у нас самые дешевые цены! Успей закупиться'},
			{'Работает АЗС','Работает АЗС №*, у нас самое качественное топливо. Ждем вас'},
			{'Работает аммунация','Работает аммунация №*, у нас самые качественные боеприпасы. '},
			{'Работает СТО по ремонту','Работает СТО по ремонту двигателей в д. *. У нас все дешево'},
			{'Работает СТО по тюнингу','Работает СТО в г. *, быстрый и качественный тюнинг вашего автомобиля'},
			{'Работает ремонт одежды','Порвалась одежды? Тогда тебе в Ремонт Одежды №* в д.'},
			{'Работает школа танцев','Хочешь чтобы все девочки были твои? Тебе в школу танцев г. '},
			{'Работает магазин одежды','Не хочешь выглядеть как бомж? Тогда тебе в магазин одежды №'},
			{'Работает нефтевышка', 'Самая лучшая нефть только у нас! Приезжай на нефтевышку № '}
		},{'Собеседования гетто/мафии',
			{'Warlock MC','Проходит собеседование в бар "Warlock MC". Ждем в баре'},
			{'Russian Mafia','Проходит собеседование в ЧОП "Russian Mafia". Встреча у особняка'},
			{'LCN','Проходит набор в гольф-клуб "La Cosa Nostra". Встреча у особняка'},
			{'Yakuza','Проходит собеседование в японский ресторан "Yakuza". Встреча в ресторане'},
			{'Tierra Robada Bikers', 'Проходит собеседование в бар "Tierra Robada Bikers". Ждем в баре'},
			{'Night Wolfs','Проходит собеседование в БК "Night Wolfs". Желающих ждём на районе'},
			{'Groove','Проходит набор в БК "Groove".  Желающих ждём на районе'},
			{'The Ballas','Проходит набор в БК "Ballas". Желающих ждём на районе'},
			{'The Vagos','Проходит набор в БК "Vagos". Желающих ждём на районе'},
			{'The Aztecas','Проходит набор в БК "Aztec". Желающих ждём на районе'},
			{'The Rifa','Проходит набор в БК "Rifa". Желающих ждём на районе'}
		},{'Собеседования госс',
			{'СМИ','Хочешь хорошее настроение каждый день? Тогда тебе на собеседование в СМИ *'},
			{'ПД','Хочешь стать как Batman? Тогда тебе на собеседование в полицию г. '},
			{'МЗ','Хочешь быть как доктор "Айболит"? Устраивайся в больницу г. '},
			{'ГЦЛ','Нравится давать людям новые знания? Тогда тебе на собеседование в ГЦЛ'},
			{'ТСР','Хотите помочь Штату? Тогда устраивайся в Тюрьму Строгого Режима'},
			{'ЦБ','Хочешь проводить операции со счетами? Приходит собеседование в Центральный Банк'},
			{'МО','Хотите отдать долг Штату? Приходи на призыв в армию г. '},
			{'СТК', 'Хочешь много зарабатывать? Устраивайся в Страховую Компанию'},
			{'Пра-во','Вы всегда хотели работать с бумагами? Тогда Вам к нам на собеседование в Мэрию'}
		},{'Семьи',
			{'Со всеми Улучшений', 'Семья "" со всеми улучшениями ищет родственников. Встреча '},
			{'Без Улучшений', 'Семья * ищет родственников. Встреча '},
			{'Ищу семью', 'Ищу семью. О себе при встрече. Просьба связаться'}
		},{'Покупка/продажа талонов',
			{'Куплю семейные талоны','Куплю "Семейные талоны". Бюджет: '},
			{'Продам семейные талоны','Продам "Семейные талоны". Цена: */шт'},
			{'Куплю семейные талоны (кол-во)','Куплю "Семейные талоны" в количестве * штук. Бюджет: '},
			{'Продам семейные талоны (кол-во)','Продам "Семейные талоны" в количестве * штук. Цена: */шт'}
		},{'Покупка/продажа гражданских талонов',
			{'Куплю гражданские талоны','Куплю "Гражданские талоны". Бюджет: '},
			{'Продам гражданские талоны','Продам "Гражданские талоны". Цена: */шт'},
			{'Куплю гражданские талоны (кол-во)','Куплю "Гражданские талоны" в количестве * штук. Бюджет: '},
			{'Продам гражданские талоны (кол-во)','Продам "Гражданские талоны" в количестве * штук. Цена: */шт'}
		},{'Покупка/продажа ресурсов/подарков',
			{'Куплю ресурсы','Куплю ресурс "". Бюджет: */шт'},
			{'Продам ресурсы','Продам ресурс "". Цена: */шт'},
			{'Куплю подарки','Куплю * подарков. Бюджет: */шт'},
			{'Продам подарки','Продам * подарков. Цена: */шт'}
		},{'Покупка/Продажа "д/т, телефонов, модификаций"',
			{'Куплю тюнинг','Куплю деталь тюнинга "" для а/м. Бюджет:'},
			{'Продам тюнинг','Продам деталь тюнинга "" для а/м. Цена:'},
			{'Куплю телефон','Куплю телефон фирмы "". Бюджет:'},
			{'Продам телефон ','Продам телефон фирмы "". Цена: '},
			{'Куплю наклейку ','Куплю наклейку "" для а/м. Бюджет:'},
			{'Продам наклейку ','Продам наклейку "" для а/м. Цена:'},
			{'Куплю м/д ','Куплю модификацию "" для а/м "". Бюджет:'},
			{'Продам м/д ','Продам модификацию "" для а/м "". Цена:'}
		},{'Покупка/продажа видеокарт, смазки и охлада',
			{'Продам видеокарту BTC', 'Продам видеокарту "BTC". Цена: '},
			{'Куплю видеокарту BTC', 'Куплю видеокарту "BTC". Бюджет: '},
			{'Продам видеокарту поколение BTC', 'Продам видеокарту "BTC" * поколения. Цена: '},
			{'Куплю видеокарту поколение BTC', 'Куплю видеокарту "BTC" * поколения. Бюджет: '},
			{'Продам видеокарту ARZ', 'Продам видеокарту "ASC". Цена: '},
			{'Куплю видеокарту ARZ', 'Куплю видеокарту "ASC". Бюджет: '},
			{'Продам видеокарту ARZ поколение', 'Продам видеокарту "ASC" * поколения. Цена: '},
			{'Куплю видеокарту ARZ поколение', 'Куплю видеокарту "ASC" * поколения. Бюджет: '},
			{'Продам охлад BTC', 'Продам охлаждающую жидкость для видеокарты "BTC". Цена: '},
			{'Куплю охлад BTC', 'Куплю охлаждающую жидкость для видеокарты "BTC". Бюджет: '},
			{'Продам смазку BTC', 'Продам смазки для разгона видеокарты "BTC". Цена: '},
			{'Куплю смазку BTC', 'Куплю смазки для разгона видеокарты "BTC". Бюджет: '},
			{'Продам охлад для ARZ', 'Продам охлаждающую жидкость для видеокарты "ASC". Цена: '},
			{'Куплю охлад для ARZ', 'Куплю охлаждающую жидкость для видеокарты "ASC". Бюджет: '},
			{'Продам смазку для ARZ', 'Продам смазку для разгона видеокарты "ASC". Цена: '},
			{'Куплю смазку для ARZ', 'Куплю смазку для разгона видеокарты "ASC". Бюджет: '}
		},{'Аренда',
			{'Сдам а/м', 'Сдам в аренду а/м *. Цена: '},
			{'Сдам фуру', 'Сдам в аренду фуру *. Цена: '},
			{'Сдам самолет', 'Сдам в аренду самолет *. Цена: '},
			{'Сдам а/с', 'Сдам в аренду а/с *. Цена: '},
			{'Сдам лодку', 'Сдам в аренду лодку *. Цена: '},
			{'Возьму а/м', 'Возьму в аренду а/м *. Бюджет: '},
			{'Возьму фуру', 'Возьму в аренду фуру *. Бюджет: '},
			{'Возьму самолет', 'Возьму в аренду самолет *. Бюджет: '},
			{'Возьму а/с', 'Возьму в аренду а/с *. Бюджет: '},
			{'Возьму лодку', 'Возьму в аренду лодку *. Бюджет: '}
		},{'Разное (Az, EXP.,Ларцы)',
			{'Куплю AZ', 'Куплю талон "Предаваемые AZ-Coin". Бюджет: '},
			{'Продам AZ', 'Продам талон "Предаваемые AZ-Coin". Цена: '},
			{'Куплю сертификат', 'Куплю сертификат "". Бюджет: '},
			{'Продам сертификат', 'Продам сертификат "". Цена: '},
			{'Куплю EXP', 'Куплю талон "Передаваемые EXP". Бюджет: '},
			{'Продам EXP', 'Продам талон "Передаваемые EXP". Цена: '},
			{'Куплю ларцы', 'Куплю ларцы "". Бюджет: '},
			{'Продам ларцы', 'Продам ларцы "". Цена: '}
		}
	}
	nHelpEsterSet = {
		{'name','duty','tagCNN','city','server','music'},
		{'имя и фамилия', 'должность', 'тег в депортамент', 'город', 'имя штата', 'Музыкальная заставка'},
		{'Keith Flint', 'Стажер', 'СМИ ЛВ', 'Лас-Вентурас', 'Юма', '<<< Музыкальная заставка радиостанции Prodigy News >>>'},
		{'Ваше имя', 'Ваша должность', 'Тег в депортамент', 'Город вашей СМИ', 'Название вашего сервера', 'Музыкальная заставка'}
	}
	newsHelpEsters = {
		['reset'] = 'bit4',
		['settings'] = {
			['name'] = '',
			['duty'] = '',
			['tagCNN'] = 'СМИ ЛВ',
			['city'] = 'Лас-Вентурас',
			['server'] = 'Юма',
			['music'] = '<<< Музыкальная заставка радиостанции Prodigy News >>>',
			['delay'] = 4
		},
		['events'] = {
			['write'] = {'Написать в /news', '/news {tag}'},
			['actions'] = {
				{'      Начать \n(RP Действие)',
					'/me подошел к рабочему столу и включил ноутбук рабочий',
					'/do Спустя 30 секунд ноутбук был включен.',
					'/me включил микрофон и достал из ящика наушники',
					'/me подсоеденил все к сети питания',
					'/do Вскоре все было готово.',
					'/me надел наушники на голову',
					'/me пододвинул кресло к себе, сел на него и приготовился к эфиру',
					'/todo Раз, два, три - это проверка связи!*говоря в микрофон',
					'/do Всё работает и готово к трансляции.'
				}, {'    Закончить \n(RP Действие)',
					'/me выключил микрофон и снял наушники с головы',
					'/me убрал наушники в ящик рабочего стола',
					'/me нажал пару кнопок и выключил рабочий ноутбук',
					'/do Вся аппаратура была успешно отключена.',
					'/me отодвинул кресло, встал с него и направился к выходу'
				}, ['name'] = 'actions'
			},
			['mathem'] = {
				{'Начать эфир',
					'/d [{tagCNN}]-[СМИ] Занимаю развлекательную волну 114.6 FM. Просьба не перебивать!',
					'/news {music}',
					'/news {tag}Приветствую вас, дорогие слушатели штата {server}.',
					'/news {tag}У микрофона {duty} СМИ г. {city}',
					'/news {tag}{name}!',
					'/news {tag}Сейчас пройдет прямой эфир на тему "Математика".',
					'/news {tag}Просьба отложить все дела и поучаствовать!',
					'/news {tag}Объясняю правила мероприятия...',
					'/news {tag}Я задаю математический пример, а слушатели должны написать ответ.',
					'/news {tag}Первый гражданин, который ответит правильно — получает балл. Играем до {scores} баллов.',
					'/news {tag}Приз на сегодня составляет {prize} долларов штата {server}.',
					'/news {tag}Деньги небольшие, но пригодятся каждому.',
					'/news {tag}Напоминаю, что писать сообщения нужно в радиоцентр...',
					'/news {tag}Доставайте свои телефоны, открывайте контакты и «Написать в СМИ»,',
					'/news {tag}Главное, выбирайте радиостанцию г. {city} и отправляйте свой ответ.',
					'/news {tag}Ну что ж, давайте начинать!'
				}, {'Следующий пример',
					'/news {tag}Следующий пример...'
				}, {'Стоп!',
					'/news {tag}Стоп! Стоп! Стоп!'
				}, {'Тех. неполадки!',
					'/news {tag}Тех. неполадки! Не переключайтесь, скоро продолжим...'
				}, {'Первым был',
					'/news {tag}Первым был {ID}! И у него уже {scoreID} правильных ответов!'
				}, {'Назвать победителя',
					'/news {tag}И у нас есть победитель!',
					'/news {tag}И это...',
					'/news {tag}{ID}! Так как именно Вы набрали {scores} правильных ответов!',
					'/news {tag}{ID}, я вас поздравляю! Ваш выиграшь {prize}$!',
					'/news {tag}{ID}, я прошу Вас приехать к нам...',
					'/news {tag}В радиоцентр г. {city} за получением своей награды.'
				}, {'Закончить эфир',
					'/news {tag}Ну что ж, дорогие слушатели!',
					'/news {tag}Пришло время попрощаться с вами.',
					'/news {tag}Сегодня мы изучали математику вместе со мной.',
					'/news {tag}Думаю интересное вышло мероприятие…',
					'/news {tag}С вами был {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Будьте грамотными и всего хорошего Вам и вашим близким!',
					'/news {tag}До встречи в эфире!!!',
					'/news {music}',
					'/d [{tagCNN}]-[СМИ] Освободил развлекательную волну 114.6 FM. Спасибо за внимание!'
				}, ['name'] = 'mathem', ['tag'] = '[Математика]: '
			},
			['chemic'] = {
				{'Начать эфир',
					'/d [{tagCNN}]-[СМИ] Занимаю развлекательную волну 114.6 FM. Просьба не перебивать!',
					'/news {music}',
					'/news {tag}Приветствую вас, дорогие слушатели штата {server}.',
					'/news {tag}У микрофона {name}, {duty} СМИ г. {city}',
					'/news {tag}Сейчас пройдет прямой эфир на тему "Химические элементы".',
					'/news {tag}Просьба отложить все дела и поучаствовать...',
					'/news {tag}Объясняю правила мероприятия...',
					'/news {tag}Я называю какой-то химический элемент из таблицы Менделеева,...',
					'/news {tag}...а вы должны написать название этого элемента.',
					'/news {tag}Например, "О" — "Кислород".',
					'/news {tag}Гражданин, который правильно и быстрее всех напишет...',
					'/news {tag}...{scores} таких элемента, побеждает в мероприятии.',
					'/news {tag}Он или она забирает денежный приз.',
					'/news {tag}Приз на сегодня составляет {prize} долларов.',
					'/news {tag}Деньги небольшие, но пригодятся каждому.',
					'/news {tag}Напоминаю, что писать сообщения нужно в радиоцентр...',
					'/news {tag}Доставайте свои телефоны, выбирайте контакт «Написать в СМИ»...',
					'/news {tag}...выбирайте радиостанцию г. {city} и отправляете ответ.',
					'/news {tag}Сейчас я посмотрю интересные элементы и мы начнем!'
				}, {'Следующий элемент',
					'/news {tag}Следующий элемент...'
				}, {'Стоп!',
					'/news {tag}Стоп! Стоп! Стоп!'
				}, {'Тех. неполадки!',
					'/news {tag}Тех. неполадки! Не переключайтесь, скоро продолжим...'
				}, {'Первым был',
					'/news {tag}Первым был {ID}! И у него уже {scoreID} правильных ответов!'
				}, {'Назвать победителя',
					'/news {tag}И у нас есть победитель!',
					'/news {tag}И это...',
					'/news {tag}{ID}! Так как именно Вы набрали {scores} правильных ответов!',
					'/news {tag}{ID}, я вас поздравляю! Ваш выиграшь {prize}$!',
					'/news {tag}{ID}, я прошу Вас приехать к нам...',
					'/news {tag}В радиоцентр г. {city} за получением своей награды.'
				}, {'Закончить эфир',
					'/news {tag}Ну что ж, дорогие слушатели!',
					'/news {tag}Пришло время попрощаться с вами.',
					'/news {tag}Сегодня мы узнали некоторые химические элементы.',
					'/news {tag}Думаю интересное вышло мероприятие…',
					'/news {tag}С вами был {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Будьте грамотными и всего хорошего Вам и вашим близким!',
					'/news {tag}До встречи в эфире!!!',
					'/news {music}',
					'/d [{tagCNN}]-[СМИ] Освободил развлекательную волну 114.6 FM. Спасибо за внимание!'
				}, ['name'] = 'chemic', ['tag'] = '[Хим.Элементы]: '
			},
			['greet'] = {
				{'Начать эфир',
					'/d [{tagCNN}]-[СМИ] Занимаю развлекательную волну 114.6 FM. Просьба не перебивать!',
					'/news {music}',
					'/news {tag}Приветствую вас, дорогие слушатели штата {server}.',
					'/news {tag}У микрофона {name}, {duty} СМИ г. {city}.',
					'/news {tag}Сейчас пройдет прямой эфир на тему "Приветы и поздравления".',
					'/news {tag}Просьба отложить все дела и поучаствовать...',
					'/news {tag}Объясняю правила мероприятия...',
					'/news {tag}Слушателям необходимо отправлять сообщения с приветами и...',
					'/news {tag}...поздравлениями в наше СМИ.',
					'/news {tag}А ведущий будет зачитывать их на весь штат {server}.',
					'/news {tag}Напоминаю, что писать сообщения нужно в радиоцентр...',
					'/news {tag}Доставайте свои телефоны и выбирайте контакт «Написать в СМИ»...',
					'/news {tag}...выбирайте радиостанцию г. {city} и отправляете ответ.',
					'/news {tag}Мероприятие будет длится около {time} минут, и я постараюсь...',
					'/news {tag}...передать приветы всем желающим.',
					'/news {tag}И так, давайте начнем. Жду ваши сообщения!'
				}, {'Передать привет',
					'/news {tag}{ID} передаёт привет {toID}!'
				}, {'Тех. неполадки!',
					'/news {tag}Тех. неполадки! Не переключайтесь, скоро продолжим...'
				}, {'Закончить эфир',
					'/news {tag}Ну что ж, дорогие слушатели!',
					'/news {tag}Пришло время прощаться с вами.',
					'/news {tag}Сегодня вы передали привет своим знакомым и близким...',
					'/news {tag}...с помощью нашего эфира.',
					'/news {tag}Думаю интересное вышло мероприятие...',
					'/news {tag}С вами был {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Будьте грамотными и всего хорошего Вам и вашим близким!',
					'/news {tag}До встречи в эфире!!!',
					'/news {music}',
					'/d [{tagCNN}]-[СМИ] Освободил развлекательную волну 114.6 FM. Спасибо за внимание!'
				}, ['name'] = 'greet', ['tag'] = '[Приветы]: '
			},
			['tohide'] = {
				{'Начать эфир',
					'/d [{tagCNN}]-[СМИ] Занимаю развлекательную волну 114.6 FM. Просьба не перебивать!',
					'/news {music}',
					'/news {tag}Приветствую вас, дорогие слушатели штата {server}.',
					'/news {tag}У микрофона {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Сейчас пройдет прямой эфир на тему «Прятки».',
					'/news {tag}Просьба отложить все дела и поучаствовать...',
					'/news {tag}Объясняю правила мероприятия...',
					'/news {tag}Я нахожусь на определенном месте на территории штата {server}...',
					'/news {tag}... и описываю свою местоположение.',
					'/news {tag}Ваша задача — найти меня.',
					'/news {tag}Звучит чертовски просто, но это не так...',
					'/news {tag}Гражданин, который сможет найти меня, должен сказать фразу-ключ.',
					'/news {tag}Без этого «ключа» Вы не сможете получить денежный приз.',
					'/news {tag}Фраза такая: «{phrase}»',
					'/news {tag}Первый, кто произнесет фразу, забирает денежный приз.',
					'/news {tag}Приз на сегодня составляет {prize} долларов.',
					'/news {tag}Деньги небольшие, но пригодятся каждому.',
					'/news {tag}Если в течении {time} минут никто не сможет меня найти, то я...',
					'/news {tag}...называю свое местоположение в GPS.',
					'/news {tag}И тогда вы точно меня найдете...',
					'/news {tag}Игра объявляется начатой!',
				}, {'Назвать победителя',
					'/news {tag}Стоп игра, господа, у нас есть победитель «Пряток»!',
					'/news {tag}Первым был {ID}! Поздравляю вас, ваш выйграшь {prize}.'
				}, {'Тех. неполадки!',
					'/news {tag}Тех. неполадки! Не переключайтесь, скоро продолжим...'
				}, {'Закончить эфир',
					'/news {tag}Ну что ж, дорогие слушатели!',
					'/news {tag}Пришло время прощаться с вами.',
					'/news {tag}Сегодня вы попытались найти меня на территории штата {server}.',
					'/news {tag}И одному гражданину это получилось, с этим мы его можем поздравить!',
					'/news {tag}Думаю интересное вышло мероприятие...',
					'/news {tag}С вами был {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Будьте грамотными и всего хорошего Вам и вашим близким!',
					'/news {tag}До встречи в эфире!!!',
					'/news {music}',
					'/d [{tagCNN}]-[СМИ] Освободил развлекательную волну 114.6 FM. Спасибо за внимание!'
				}, ['name'] = 'tohide', ['tag'] = '[Прятки]: '
			},
			['capitals'] = {
				{'Начать эфир',
					'/d [{tagCNN}]-[СМИ] Занимаю развлекательную волну 114.6 FM. Просьба не перебивать!',
					'/news {music}',
					'/news {tag}Приветствую вас, дорогие слушатели штата {server}.',
					'/news {tag}У микрофона {name}, {duty} СМИ г. {city}.',
					'/news {tag}Сейчас пройдет прямой эфир на тему "Столицы".',
					'/news {tag}Просьба отложить все дела и поучаствовать...',
					'/news {tag}Объясняю правила мероприятия...',
					'/news {tag}Я говорю название страны в любой точке мира, ...',
					'/news {tag}... а вы должны написать сообщение с ответом на мой вопрос.',
					'/news {tag}Первый гражданин, кто ответил правильно, получает один балл.',
					'/news {tag}Всего можно заработать {scores} балла!',
					'/news {tag}Первый, кто достигнет эту отметку, забирает денежный приз.',
					'/news {tag}Приз на сегодня составляет {prize} долларов.',
					'/news {tag}Деньги небольшие, но пригодятся каждому.',
					'/news {tag}Напоминаю, что писать сообщения нужно в радиоцентр…',
					'/news {tag}Доставайте свои телефоны, открывайте контакты и «Написать в СМИ»...',
					'/news {tag}... выбирайте радиостанцию г. {city} и отправляете ответ.',
					'/news {tag}И так... мы начинаем!!!'
				}, {'Следующий пример',
					'/news {tag}Следующий вопрос...'
				}, {'Стоп!',
					'/news {tag}Стоп! Стоп! Стоп!'
				}, {'Тех. неполадки!',
					'/news {tag}Тех. неполадки! Не переключайтесь, скоро продолжим...'
				}, {'Первым был',
					'/news {tag}Первым был {ID}! И у него уже {scoreID} правильных ответов!'
				}, {'Назвать победителя',
					'/news {tag}И у нас есть победитель!',
					'/news {tag}И это {ID}',
					'/news {tag}{ID}! Так как именно Вы набрали {scores} правильных ответов!',
					'/news {tag}Вы набрали нужное кол-во баллов.',
					'/news {tag}{ID}, я вас поздравляю! Ваш выигрыш {prize}$!',
					'/news {tag}{ID}, я прошу Вас приехать к нам...',
					'/news {tag}В радиоцентр г. {city} за получением своей награды.'
				}, {'Закончить эфир',
					'/news {tag}Ну что ж, дорогие слушатели!',
					'/news {tag}Пришло время прощаться с вами.',
					'/news {tag}Сегодня мы с вами узнали некоторые страны и их столицы.',
					'/news {tag}Думаю вам было интересно...',
					'/news {tag}С вами был {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Будьте грамотными и берегите своих близких!',
					'/news {tag}До встречи в эфире!!!',
					'/news {music}',
					'/d [{tagCNN}]-[СМИ] Освободил развлекательную волну 114.6 FM, до связи!'
				}, ['name'] = 'capitals', ['tag'] = '[Столицы]: '
			},
			['mirror'] = {
				{'Начать эфир',
					'/d [{tagCNN}]-[СМИ] Занимаю развлекательную волну 114.6 FM. Просьба не перебивать!',
					'/news {music}',
					'/news {tag}Приветствую вас, дорогие слушатели штата {server}.',
					'/news {tag}У микрофона {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Сейчас пройдет прямой эфир на тему «Зеркало».',
					'/news {tag}Просьба отложить все дела и поучаствовать...',
					'/news {tag}Объясняю правила мероприятия...',
					'/news {tag}Я называю какое-то слово в инверсированном порядке.',
					'/news {tag}То есть привычное нам слово наоборот, ...',
					'/news {tag}... например, «Яблоко» - «Околбя».',
					'/news {tag}Понять что это за слово не так просто, но уверен, что вы справитесь.',
					'/news {tag}Гражданин, который правильно и быстрее всех напишет ...',
					'/news {tag}... {scores} таких слова, побеждает в мероприятии.',
					'/news {tag}И забирает денежный приз.',
					'/news {tag}Приз на сегодня составляет {prize} долларов.',
					'/news {tag}Деньги небольшие, но пригодятся каждому.',
					'/news {tag}Напоминаю, что писать сообщения нужно в радиоцентр...',
					'/news {tag}Доставайте свои телефоны, открывайте контакты и «Написать в СМИ» ...',
					'/news {tag}... выбирайте радиостанцию г. {city} и отправляете ответ.',
					'/news {tag}Сейчас я поищу интересные слова и мы начнем!'
				}, {'Следующий пример',
					'/news {tag}Следующий пример...'
				}, {'Стоп!',
					'/news {tag}Стоп! Стоп! Стоп!'
				}, {'Тех. неполадки!',
					'/news {tag}Тех. неполадки! Не переключайтесь, скоро продолжим...'
				}, {'Первым был',
					'/news {tag}Первым был {ID}! И у него уже {scoreID} правильных ответов!'
				}, {'Назвать победителя',
					'/news {tag}И у нас есть победитель!',
					'/news {tag}И это...',
					'/news {tag}{ID}! Так как именно Вы набрали {scores} правильных ответов!',
					'/news {tag}{ID}, я вас поздравляю! Ваш выиграшь {prize}$!',
					'/news {tag}{ID}, я прошу Вас приехать к нам...',
					'/news {tag}В радиоцентр г. {city} за получением своей награды.'
				}, {'Закончить эфир',
					'/news {tag}Ну что ж, дорогие слушатели!',
					'/news {tag}Пришло время прощаться с вами.',
					'/news {tag}Сегодня вы учились вместе со мной разгадывать слова с инверсией.',
					'/news {tag}Так сказать, учились новому языку вместе с любимым ведущим!',
					'/news {tag}Думаю интересное вышло мероприятие...',
					'/news {tag}С вами был {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Будьте грамотными и всего хорошего Вам и вашим близким!',
					'/news {tag}До встречи в эфире!!!',
					'/news {music}',
					'/d [{tagCNN}]-[СМИ] Освободил развлекательную волну 114.6 FM, до связи!'
				}, ['name'] = 'mirror', ['tag'] = '[Зеркало]: ',
				['notepad'] = 'Анишам = Машина\nАгинк = Книга\nЛотс = Стол\nАкчур = Ручка\nЬтаворк = Кровать\nАклобтуф = Футболка\nСуболг = Глобус\nАнитрак = Картина\nЛутс = Стул\nЕинетсар = Растение\nАде = Еда\nАдогоп = Погода\nРетюьпмок = Компьютер\nАклерат = Тарелка\nАнетс = Стена\nТок = Кот\nЬдевдем = Медведь\nАбыр = Рыба\nЕьлесев = Веселье\nНизагам = Магазин\n'
			},
			['interpreter'] = {
				{'Начать эфир',
					'/d [{tagCNN}]-[СМИ] Занимаю развлекательную волну 114.6 FM. Просьба не перебивать!',
					'/news {music}',
					'/news {tag}Приветствую вас, дорогие слушатели штата {server}.',
					'/news {tag}У микрофона {duty} СМИ г. {city}',
					'/news {tag}{name}!',
					'/news {tag}Сейчас пройдет прямой эфир на тему "Математика".',
					'/news {tag}Просьба отложить все дела и поучаствовать!',
					'/news {tag}Я говорю слово на {language}ом языке, а вы должны написать ответ.',
					'/news {tag}Проверим ваши знания данного языка, это не самая простая задача...',
					'/news {tag}Первый гражданин, который ответит правильно — получает балл. Играем до {scores} баллов.',
					'/news {tag}Приз на сегодня составляет {prize} долларов штата {server}.',
					'/news {tag}Деньги небольшие, но пригодятся каждому.',
					'/news {tag}Напоминаю, что писать сообщения нужно в радиоцентр...',
					'/news {tag}Доставайте свои телефоны, открывайте контакты и «Написать в СМИ»,',
					'/news {tag}Главное, выбирайте радиостанцию г. {city} и отправляйте свой ответ.',
					'/news {tag}Ну что ж, давайте начинать!'
				}, {'Следующий пример',
					'/news {tag}Следующий слово такое ...'
				}, {'Стоп!',
					'/news {tag}Стоп! Стоп! Стоп!'
				}, {'Тех. неполадки!',
					'/news {tag}Тех. неполадки! Не переключайтесь, скоро продолжим...'
				}, {'Первым был',
					'/news {tag}Первым был {ID}! И у него уже {scoreID} правильных ответов!'
				}, {'Назвать победителя',
					'/news {tag}И у нас есть победитель!',
					'/news {tag}И это...',
					'/news {tag}{ID}! Так как именно Вы набрали {scores} правильных ответов!',
					'/news {tag}{ID}, я вас поздравляю! Ваш выиграшь {prize}$!',
					'/news {tag}{ID}, я прошу Вас приехать к нам...',
					'/news {tag}В радиоцентр г. {city} за получением своей награды.'
				}, {'Закончить эфир',
					'/news {tag}Ну что ж, дорогие слушатели!',
					'/news {tag}Пришло время попрощаться с вами.',
					'/news {tag}Сегодня вы изучали {language}ий язык, вместе со мной.',
					'/news {tag}Думаю интересное вышло мероприятие…',
					'/news {tag}С вами был {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Будьте грамотными и всего хорошего Вам и вашим близким!',
					'/news {tag}До встречи в эфире!!!',
					'/news {music}',
					'/d [{tagCNN}]-[СМИ] Освободил развлекательную волну 114.6 FM. Спасибо за внимание!'
				}, ['name'] = 'interpreter', ['tag'] = '[Переводчики]: '
			}
		}
	}
	langArr = {
		['tags'] = {'ru', 'en', 'fr', 'es', 'de', 'it'--[[, 'zh', 'kk']]},
		['ru'] = {
			'Машина', 'Книга', 'Стол', 'Ручка', 'Кровать', 'Футболка', 'Глобус', 'Картина', 'Стул', 'Растение',
			'Еда', 'Погода', 'Компьютер', 'Тарелка', 'Стена', 'Кот', 'Медведь', 'Рыба', 'Веселье', 'Магазин'
		},
		['en'] = {
			'Car', 'Book', 'Table', 'Pen', 'Bed', 'T-shirt', 'Globe', 'Picture', 'Chair', 'Plant', 'Meal',
			'Weather', 'Computer', 'Plate', 'Wall', 'Cat', 'Bear', 'Fish', 'Fun', 'Shop'
		},
		['fr'] = {
			'Machine', 'Livre', 'Bureau', 'Poignee', 'Lit', 'T-shirt', 'Globe', 'Peinture', 'Chaise', 'Plante',
			'Repas', 'Temps', 'Ordinateur', 'Assiette', 'Mur', 'Chat', 'Ours', 'Poisson', 'Gaiete', 'Boutique'
		},
		['es'] = {
			'Maquina', 'Libro', 'Mesa', 'Manija', 'Cama', 'Camiseta', 'Globo', 'Pintura', 'Silla', 'Planta',
			'Comida', 'Tiempo', 'Ordenador', 'Plato', 'Pared', 'Gato', 'Oso', 'Pez', 'Alegria', 'Tienda'
		},
		['de'] = {
			'Auto', 'Das Buch', 'Der Tisch', 'Stift', 'Bett', 'T-Shirt', 'Der Globus', 'Das Bild', 'Der Stuhl', 'Die Pflanze',
			'Essen', 'Das Wetter', 'Computer', 'Teller', 'Die Wand', 'Der Kater', 'Der Bar', 'Fisch', 'Spab', 'Geschaft'
		},
		['it'] = {
			'Macchina', 'Libro', 'Tavolo', 'Maniglia', 'Letto', 'Maglia', 'Globo', 'Dipinto', 'Sedia', 'Pianta',
			'Pasto', 'Tempo', 'Computer', 'Scodellino', 'Parete', 'Gatto', 'Orso', 'Pesce', 'Allegria', 'Negozio'
		}--[[,
		['zh'] = {
			'汽车', '书', '表', '一支笔', '床', 'T恤衫', '全球', '图片', '椅子', '植物', '膳食', '天气情况',
			'电脑', '盘子', '墙面', '的猫', '是熊', '鱼', '乐趣', '商店'
		},
		['kk'] = {
			'Машина', 'Кітап', 'Үстел', 'Қалам', 'Төсек', 'Футболка', 'Глобус', 'Сурет', 'Орындық', 'Өсімдік',
			'Тамақ', 'Ауа райы', 'Компьютер', 'Табақ', 'Қабырға', 'Мысық', 'Аю', 'Балық', 'Көңілді', 'Дүкен'
		}]]
	}
	newsAutoBind = {{'..'},
		{'тт', 'Twin Turbo'},
		{'анб', 'антибиотики'},
		{'кр', 'коронавирус'},
		{'цв', 'цвета'},
		{'см', 'Санта-Мария '},
		{'фея', '"Бородатая фея" '},
		{'наш', 'со всеми нашивками '},
		{'ищр', 'ищет родных'},
		{'грув', 'БК "Грув". '},
		{'баллас', 'БК "Баллас". '},
		{'вагос', 'БК "Вагос". '},
		{'ацтек', 'БК "Ацтек". '},
		{'рифа', 'БК "Рифа". '},
		{'дпк', 'д. Паломино-Крик. '},
		{'дтр', 'д. Тиерро-Робада. '},
		{'дфк', 'д. Форт-Карсон. '},
		{'дрк', 'д. Ред-Каунтри. '},
		{'дпх', 'д. Паломино-Хиллс. '},
		{'дап', 'д. Ангел-Пайн. '},
		{'гвв', 'г. Вайн-Вуд. '},
		{'вв', 'Вайн-Вуд. '},
		{'вг', 'военном городке.'},
		{'00', '.OOO.OOO$'},
		{'01', '.OOO$/шт'},
		{'02', '.OOO$/час'},
		{'про', 'РЛВ || ПРО -> '},
		{'опш', 'одежду пошива '},
		{'осб', 'одежду с биркой '},
		{'лс', 'Лос-Сантос'},
		{'сф', 'Сан-Фиерро'},
		{'лв', 'Лас-Вентурас'},
		{'лм', 'любой марки'},
		{'опл:', 'Оплата: '},
		{'оплд', 'Оплата: Договорная'},
		{'лш', 'лет в штате.'},
		{'ор', 'в опасном районе. '}
	}
	newsKeyBind = {
		{{vk.VK_CONTROL, vk.VK_1}, 'Бюджет: Свободный'},
		{{vk.VK_CONTROL, vk.VK_2}, 'Цена: Договорная'},
		{{vk.VK_CONTROL, vk.VK_NUMPAD7}, 'г. Лос-Сантос. '},
		{{vk.VK_CONTROL, vk.VK_NUMPAD8}, 'г. Сан-Фиерро. '},
		{{vk.VK_CONTROL, vk.VK_NUMPAD9}, 'г. Лас-Вентурас. '},
		{{vk.VK_MENU, vk.VK_1}, 'Бюджет: '},
		{{vk.VK_MENU, vk.VK_2}, 'Цена: '},
		{{vk.VK_CONTROL, vk.VK_5}, 'дом с гаражем'},
		{{vk.VK_MENU, vk.VK_Q}, 'а/м '},
		{{vk.VK_MENU, vk.VK_W}, 'м/ц '},
		{{vk.VK_MENU, vk.VK_E}, 'в/т '},
		{{vk.VK_MENU, vk.VK_R}, 'а/с '},
		{{vk.VK_MENU, vk.VK_T}, 'б/з '},
		{{vk.VK_MENU, vk.VK_Y}, 'с/т '},
		{{vk.VK_MENU, vk.VK_U}, 'в/с '},
		{{vk.VK_MENU, vk.VK_I}, 'т/с '},
		{{vk.VK_MENU, vk.VK_6}, '$'}
	}
	callbacks = {
		calc = ffi.cast('int (*)(ImGuiInputTextCallbackData* data)', function(data)
			local txtIpt = ffi.string(data.Buf)
			local txtMatch = '[^%d%+%-%^%/%(%)%*%s%.]+'
			if txtIpt:match(txtMatch) then
				local share = false
				if txtIpt:match('[\\|]+') then
					share = txtIpt:find('[\\|]+')
					data:InsertChars(share, '/')
				end
				local intCh = txtIpt:find(txtMatch)
				data:DeleteChars(intCh - 1, string.match(txtIpt:sub(intCh, intCh), '[^%w%p]') and 2 or 1)
				data.CursorPos = intCh - (share and 0 or 1)
			end
			return 0
		end),
		bindtag = ffi.cast('int (*)(ImGuiInputTextCallbackData* data)', function(data)
			local txtIpt = ffi.string(data.Buf)
			local txtMatch = '[%c][%c]'
			if txtIpt:match(txtMatch) then
				local intCh = txtIpt:find(txtMatch)
				if intCh > tmp.callBT or intCh == tmp.callBT then -- enter >; backspace <
					data:InsertChars(intCh + 1, '/news \n')
					data:DeleteChars(intCh, 1)
					data.CursorPos = intCh + 6
				else
					data:DeleteChars(intCh, 1)
				end
			end
			if tmp.callBT ~= data.CursorPos then
				tmp.callBT = data.CursorPos
			end
			return 0
		end)
	}
	hotkey = {
		no_flood = false,
		lastkey = 9999,
		MODULEINFO = {
			version = 2,
			author = 'chapo'
		},
		Text = {
			wait_for_key = 'Нажмите...',
			no_key = 'Нет'
		},
		List = {},
		EditKey = nil,
		Edit = {
			backup = {},
			new = {}
		},
		Ret = {name = nil, data = {}},
		LargeKeys = {vk.VK_SHIFT, vk.VK_SPACE, vk.VK_CONTROL, vk.VK_MENU, vk.VK_RETURN}
	}
	g_img = {['img_emmet'] = '\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1F\x15\xC4\x89\x00\x00\x01\x26\x69\x43\x43\x50\x41\x64\x6F\x62\x65\x20\x52\x47\x42\x20\x28\x31\x39\x39\x38\x29\x00\x00\x28\x15\x63\x60\x60\x32\x70\x74\x71\x72\x65\x12\x60\x60\xC8\xCD\x2B\x29\x0A\x72\x77\x52\x88\x88\x8C\x52\x60\x3F\xCF\xC0\xC6\xC0\xCC\x00\x06\x89\xC9\xC5\x05\x8E\x01\x01\x3E\x20\x76\x5E\x7E\x5E\x2A\x03\x06\xF8\x76\x8D\x81\x11\x44\x5F\xD6\x05\x99\xC5\x40\x1A\xE0\x4A\x2E\x28\x2A\x01\xD2\x7F\x80\xD8\x28\x25\xB5\x38\x99\x81\x81\xD1\x00\xC8\xCE\x2E\x2F\x29\x00\x8A\x33\xCE\x01\xB2\x45\x92\xB2\xC1\xEC\x0D\x20\x76\x51\x48\x90\x33\x90\x7D\x04\xC8\xE6\x4B\x87\xB0\xAF\x80\xD8\x49\x10\xF6\x13\x10\xBB\x08\xE8\x09\x20\xFB\x0B\x48\x7D\x3A\x98\xCD\xC4\x01\x36\x07\xC2\x96\x01\xB1\x4B\x52\x2B\x40\xF6\x32\x38\xE7\x17\x54\x16\x65\xA6\x67\x94\x28\x18\x5A\x5A\x5A\x2A\x38\xA6\xE4\x27\xA5\x2A\x04\x57\x16\x97\xA4\xE6\x16\x2B\x78\xE6\x25\xE7\x17\x15\xE4\x17\x25\x96\xA4\xA6\x00\xD5\x42\xDC\x07\x06\x82\x10\x85\xA0\x10\xD3\x00\x6A\xB4\xD0\x64\xA0\x32\x00\xC5\x03\x84\xF5\x39\x10\x1C\xBE\x8C\x62\x67\x10\x62\x08\x90\x5C\x5A\x54\x06\x65\x32\x32\x19\x13\xE6\x23\xCC\x98\x23\xC1\xC0\xE0\xBF\x94\x81\x81\xE5\x0F\x42\xCC\xA4\x97\x81\x61\x81\x0E\x03\x03\xFF\x54\x84\x98\x9A\x21\x03\x83\x80\x3E\x03\xC3\xBE\x39\x00\xC0\xC6\x4F\xFD\x10\x46\x21\x7C\x00\x00\x00\x09\x70\x48\x59\x73\x00\x00\x2E\x23\x00\x00\x2E\x23\x01\x78\xA5\x3F\x76\x00\x00\x05\xF9\x69\x54\x58\x74\x58\x4D\x4C\x3A\x63\x6F\x6D\x2E\x61\x64\x6F\x62\x65\x2E\x78\x6D\x70\x00\x00\x00\x00\x00\x3C\x3F\x78\x70\x61\x63\x6B\x65\x74\x20\x62\x65\x67\x69\x6E\x3D\x22\xEF\xBB\xBF\x22\x20\x69\x64\x3D\x22\x57\x35\x4D\x30\x4D\x70\x43\x65\x68\x69\x48\x7A\x72\x65\x53\x7A\x4E\x54\x63\x7A\x6B\x63\x39\x64\x22\x3F\x3E\x20\x3C\x78\x3A\x78\x6D\x70\x6D\x65\x74\x61\x20\x78\x6D\x6C\x6E\x73\x3A\x78\x3D\x22\x61\x64\x6F\x62\x65\x3A\x6E\x73\x3A\x6D\x65\x74\x61\x2F\x22\x20\x78\x3A\x78\x6D\x70\x74\x6B\x3D\x22\x41\x64\x6F\x62\x65\x20\x58\x4D\x50\x20\x43\x6F\x72\x65\x20\x35\x2E\x36\x2D\x63\x31\x34\x32\x20\x37\x39\x2E\x31\x36\x30\x39\x32\x34\x2C\x20\x32\x30\x31\x37\x2F\x30\x37\x2F\x31\x33\x2D\x30\x31\x3A\x30\x36\x3A\x33\x39\x20\x20\x20\x20\x20\x20\x20\x20\x22\x3E\x20\x3C\x72\x64\x66\x3A\x52\x44\x46\x20\x78\x6D\x6C\x6E\x73\x3A\x72\x64\x66\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x77\x77\x77\x2E\x77\x33\x2E\x6F\x72\x67\x2F\x31\x39\x39\x39\x2F\x30\x32\x2F\x32\x32\x2D\x72\x64\x66\x2D\x73\x79\x6E\x74\x61\x78\x2D\x6E\x73\x23\x22\x3E\x20\x3C\x72\x64\x66\x3A\x44\x65\x73\x63\x72\x69\x70\x74\x69\x6F\x6E\x20\x72\x64\x66\x3A\x61\x62\x6F\x75\x74\x3D\x22\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x78\x6D\x70\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x6E\x73\x2E\x61\x64\x6F\x62\x65\x2E\x63\x6F\x6D\x2F\x78\x61\x70\x2F\x31\x2E\x30\x2F\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x78\x6D\x70\x4D\x4D\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x6E\x73\x2E\x61\x64\x6F\x62\x65\x2E\x63\x6F\x6D\x2F\x78\x61\x70\x2F\x31\x2E\x30\x2F\x6D\x6D\x2F\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x73\x74\x45\x76\x74\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x6E\x73\x2E\x61\x64\x6F\x62\x65\x2E\x63\x6F\x6D\x2F\x78\x61\x70\x2F\x31\x2E\x30\x2F\x73\x54\x79\x70\x65\x2F\x52\x65\x73\x6F\x75\x72\x63\x65\x45\x76\x65\x6E\x74\x23\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x64\x63\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x70\x75\x72\x6C\x2E\x6F\x72\x67\x2F\x64\x63\x2F\x65\x6C\x65\x6D\x65\x6E\x74\x73\x2F\x31\x2E\x31\x2F\x22\x20\x78\x6D\x6C\x6E\x73\x3A\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3D\x22\x68\x74\x74\x70\x3A\x2F\x2F\x6E\x73\x2E\x61\x64\x6F\x62\x65\x2E\x63\x6F\x6D\x2F\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x2F\x31\x2E\x30\x2F\x22\x20\x78\x6D\x70\x3A\x43\x72\x65\x61\x74\x6F\x72\x54\x6F\x6F\x6C\x3D\x22\x41\x64\x6F\x62\x65\x20\x50\x68\x6F\x74\x6F\x73\x68\x6F\x70\x20\x43\x43\x20\x32\x30\x31\x38\x20\x28\x57\x69\x6E\x64\x6F\x77\x73\x29\x22\x20\x78\x6D\x70\x3A\x43\x72\x65\x61\x74\x65\x44\x61\x74\x65\x3D\x22\x32\x30\x32\x33\x2D\x30\x33\x2D\x31\x30\x54\x30\x34\x3A\x33\x38\x3A\x30\x33\x2B\x30\x33\x3A\x30\x30\x22\x20\x78\x6D\x70\x3A\x4D\x65\x74\x61\x64\x61\x74\x61\x44\x61\x74\x65\x3D\x22\x32\x30\x32\x33\x2D\x30\x33\x2D\x31\x30\x54\x30\x34\x3A\x33\x38\x3A\x30\x33\x2B\x30\x33\x3A\x30\x30\x22\x20\x78\x6D\x70\x3A\x4D\x6F\x64\x69\x66\x79\x44\x61\x74\x65\x3D\x22\x32\x30\x32\x33\x2D\x30\x33\x2D\x31\x30\x54\x30\x34\x3A\x33\x38\x3A\x30\x33\x2B\x30\x33\x3A\x30\x30\x22\x20\x78\x6D\x70\x4D\x4D\x3A\x49\x6E\x73\x74\x61\x6E\x63\x65\x49\x44\x3D\x22\x78\x6D\x70\x2E\x69\x69\x64\x3A\x30\x62\x34\x65\x30\x37\x61\x32\x2D\x36\x65\x39\x39\x2D\x39\x35\x34\x61\x2D\x39\x63\x64\x65\x2D\x34\x30\x35\x66\x65\x30\x64\x30\x34\x32\x31\x30\x22\x20\x78\x6D\x70\x4D\x4D\x3A\x44\x6F\x63\x75\x6D\x65\x6E\x74\x49\x44\x3D\x22\x61\x64\x6F\x62\x65\x3A\x64\x6F\x63\x69\x64\x3A\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x33\x36\x64\x31\x37\x34\x36\x35\x2D\x31\x39\x33\x38\x2D\x38\x61\x34\x32\x2D\x62\x33\x64\x62\x2D\x66\x66\x30\x64\x62\x34\x38\x66\x61\x61\x61\x39\x22\x20\x78\x6D\x70\x4D\x4D\x3A\x4F\x72\x69\x67\x69\x6E\x61\x6C\x44\x6F\x63\x75\x6D\x65\x6E\x74\x49\x44\x3D\x22\x78\x6D\x70\x2E\x64\x69\x64\x3A\x36\x65\x61\x32\x64\x63\x33\x32\x2D\x61\x38\x30\x39\x2D\x38\x37\x34\x33\x2D\x62\x36\x64\x65\x2D\x32\x39\x34\x39\x62\x61\x66\x37\x30\x34\x31\x62\x22\x20\x64\x63\x3A\x66\x6F\x72\x6D\x61\x74\x3D\x22\x69\x6D\x61\x67\x65\x2F\x70\x6E\x67\x22\x20\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x43\x6F\x6C\x6F\x72\x4D\x6F\x64\x65\x3D\x22\x33\x22\x20\x70\x68\x6F\x74\x6F\x73\x68\x6F\x70\x3A\x49\x43\x43\x50\x72\x6F\x66\x69\x6C\x65\x3D\x22\x41\x64\x6F\x62\x65\x20\x52\x47\x42\x20\x28\x31\x39\x39\x38\x29\x22\x3E\x20\x3C\x78\x6D\x70\x4D\x4D\x3A\x48\x69\x73\x74\x6F\x72\x79\x3E\x20\x3C\x72\x64\x66\x3A\x53\x65\x71\x3E\x20\x3C\x72\x64\x66\x3A\x6C\x69\x20\x73\x74\x45\x76\x74\x3A\x61\x63\x74\x69\x6F\x6E\x3D\x22\x63\x72\x65\x61\x74\x65\x64\x22\x20\x73\x74\x45\x76\x74\x3A\x69\x6E\x73\x74\x61\x6E\x63\x65\x49\x44\x3D\x22\x78\x6D\x70\x2E\x69\x69\x64\x3A\x36\x65\x61\x32\x64\x63\x33\x32\x2D\x61\x38\x30\x39\x2D\x38\x37\x34\x33\x2D\x62\x36\x64\x65\x2D\x32\x39\x34\x39\x62\x61\x66\x37\x30\x34\x31\x62\x22\x20\x73\x74\x45\x76\x74\x3A\x77\x68\x65\x6E\x3D\x22\x32\x30\x32\x33\x2D\x30\x33\x2D\x31\x30\x54\x30\x34\x3A\x33\x38\x3A\x30\x33\x2B\x30\x33\x3A\x30\x30\x22\x20\x73\x74\x45\x76\x74\x3A\x73\x6F\x66\x74\x77\x61\x72\x65\x41\x67\x65\x6E\x74\x3D\x22\x41\x64\x6F\x62\x65\x20\x50\x68\x6F\x74\x6F\x73\x68\x6F\x70\x20\x43\x43\x20\x32\x30\x31\x38\x20\x28\x57\x69\x6E\x64\x6F\x77\x73\x29\x22\x2F\x3E\x20\x3C\x72\x64\x66\x3A\x6C\x69\x20\x73\x74\x45\x76\x74\x3A\x61\x63\x74\x69\x6F\x6E\x3D\x22\x73\x61\x76\x65\x64\x22\x20\x73\x74\x45\x76\x74\x3A\x69\x6E\x73\x74\x61\x6E\x63\x65\x49\x44\x3D\x22\x78\x6D\x70\x2E\x69\x69\x64\x3A\x30\x62\x34\x65\x30\x37\x61\x32\x2D\x36\x65\x39\x39\x2D\x39\x35\x34\x61\x2D\x39\x63\x64\x65\x2D\x34\x30\x35\x66\x65\x30\x64\x30\x34\x32\x31\x30\x22\x20\x73\x74\x45\x76\x74\x3A\x77\x68\x65\x6E\x3D\x22\x32\x30\x32\x33\x2D\x30\x33\x2D\x31\x30\x54\x30\x34\x3A\x33\x38\x3A\x30\x33\x2B\x30\x33\x3A\x30\x30\x22\x20\x73\x74\x45\x76\x74\x3A\x73\x6F\x66\x74\x77\x61\x72\x65\x41\x67\x65\x6E\x74\x3D\x22\x41\x64\x6F\x62\x65\x20\x50\x68\x6F\x74\x6F\x73\x68\x6F\x70\x20\x43\x43\x20\x32\x30\x31\x38\x20\x28\x57\x69\x6E\x64\x6F\x77\x73\x29\x22\x20\x73\x74\x45\x76\x74\x3A\x63\x68\x61\x6E\x67\x65\x64\x3D\x22\x2F\x22\x2F\x3E\x20\x3C\x2F\x72\x64\x66\x3A\x53\x65\x71\x3E\x20\x3C\x2F\x78\x6D\x70\x4D\x4D\x3A\x48\x69\x73\x74\x6F\x72\x79\x3E\x20\x3C\x2F\x72\x64\x66\x3A\x44\x65\x73\x63\x72\x69\x70\x74\x69\x6F\x6E\x3E\x20\x3C\x2F\x72\x64\x66\x3A\x52\x44\x46\x3E\x20\x3C\x2F\x78\x3A\x78\x6D\x70\x6D\x65\x74\x61\x3E\x20\x3C\x3F\x78\x70\x61\x63\x6B\x65\x74\x20\x65\x6E\x64\x3D\x22\x72\x22\x3F\x3E\x1B\x2B\x61\x74\x00\x00\x00\x0D\x49\x44\x41\x54\x08\x1D\x63\xF8\xFF\xFF\x3F\x03\x00\x08\xFC\x02\xFE\xE6\x0C\xFF\xAB\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82'}
end
