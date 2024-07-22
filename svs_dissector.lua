ESCAPE_CHAR = 0xAA
FLAG_CHAR = 0x7E
svs_protocol = Proto("SVS_PROTOCOL",  "SVS_PROTOCOL")

flagstart_type =ProtoField.uint8("SVS_PROTOCOL.FLAGSTART","FlagStart",base.HEX)
id_type = ProtoField.uint8("SVS_PROTOCOL.ID","ID",base.HEX)
counter_type =ProtoField.uint8("SVS_PROTOCOL.Counter","Counter",base.DEC)
length_type =ProtoField.uint8("SVS_PROTOCOL.Length","Length",base.DEC)
typecommand_type =ProtoField.uint8("SVS_PROTOCOL.TypeCommand","TypeCommand",base.HEX)
selectedcamera_type =ProtoField.uint16("SVS_PROTOCOL.SelectedCamera","SelectedCamera",base.BIN)
parameters_type = ProtoField.uint8("SVS_PROTOCOL.Parameters","Parameters",base.HEX)
camera_capabilities = ProtoField.uint8("SVS_PROTOCOL.Capabilities","Camera Capabilities",base.HEX)
camera_status = ProtoField.uint8("SVS_PROTOCOL.Status","Camera Status",base.HEX)
camera_monitor = ProtoField.uint8("SVS_PROTOCOL.Monitor","Camera Monitor",base.HEX)
camera_ROI = ProtoField.uint8("SVS_PROTOCOL.ROI","Camera ROI",base.HEX)
camera_Polarity = ProtoField.uint8("SVS_PROTOCOL.Polarity","Camera Polarity",base.HEX)
extended_type = ProtoField.uint8("SVS_PROTOCOL.Extended","Extended",base.HEX)
reserved_type = ProtoField.uint16("SVS_PROTOCOL.Reserved","Reserved",base.HEX)
checksum_type = ProtoField.uint8("SVS_PROTOCOL.Checksum","Checksum",base.HEX)
flagstop_type =ProtoField.uint8("SVS_PROTOCOL.FLAGSTOP","FlagStop",base.HEX)

svs_protocol.fields = {flagstart_type, id_type,counter_type, length_type, typecommand_type, selectedcamera_type, parameters_type, camera_capabilities, camera_status, camera_monitor, camera_ROI, camera_Polarity, extended_type, reserved_type, checksum_type, flagstop_type}

function svs_protocol.dissector(buffer, pinfo, tree)
	pinfo.cols.protocol = svs_protocol.name;
	subtree = tree:add(svs_protocol, buffer())

	type = buffer(1, 1):uint()
	if type == 0x35 then  -- if the packet is of type commands
		mtype_str = "COMMANDS"
		command = buffer(4,1):uint() 

	elseif type == 0xCA then -- if the packet is of type status
		mtype_str = "STATUS"
		command = buffer(6,1):uint() 
	end
	
	params = buffer(7,1):uint()
	if command == 0x01 then 
		mycmd_str = "KEEP ALIVE"
		params_str = "0x00"

	elseif command == 0x02 then 
		mycmd_str = "ROI"

		if params == 0x01 then
			params_str = "FULL SCREEN"
		elseif params == 0x02 then
			params_str = "BOTTOM HALF"
		elseif params == 0x04 then
			params_str = "CENTRE BLOCK"
		elseif params == 0x08 then
			params_str = "TOP HALF"
		end

	elseif command == 0x04 then
		mycmd_str = "DAY/IR/POLARITY"

		if params == 0x01 then
			params_str = "DAY"
		elseif params == 0x02 then
			params_str = "IR/WHITE HOT"
		elseif params == 0x04 then
			params_str = "IR/BLACK HOT"
		end 	

	elseif command == 0x08 then
		mycmd_str = "NUC"

		if params == 0x01 then
			params_str = "NUC AUTOMATICO DISABILITATO"
		elseif params == 0x02 then
			params_str = "NUC AUTOMATICO ABILITATO"
		end
	end	

	subtree:add(flagstart_type,buffer(0,1)):append_text("")
	subtree:add(id_type,buffer(1,1)):append_text(" (" .. mtype_str .. ")")
	subtree:add(counter_type,buffer(2,1)):append_text("")
	subtree:add(length_type,buffer(3,1)):append_text("")

	if mtype_str == "COMMANDS" then -- if the packet is of type commands
		subtree:add(typecommand_type,buffer(4,1)):append_text(" (" .. mycmd_str .. ")")
		subtree:add(selectedcamera_type,buffer(5,2)):append_text("")
		subtree:add(parameters_type,buffer(7,1)):append_text(" (" .. params_str .. ")")
		subtree:add(reserved_type,buffer(8,2)):append_text("")
		subtree:add(checksum_type,buffer(10,1)):append_text("")
		subtree:add(flagstop_type,buffer(11,1)):append_text("")

	elseif mtype_str == "STATUS" then -- if the packet is of type status
		subtree:add(selectedcamera_type, buffer(4,2):uint()):append_text("")
		subtree:add(typecommand_type, buffer(6,1)):append_text(" (" .. mycmd_str .. ")")
		subtree:add(parameters_type, buffer(7,1)):append_text(" (" .. params_str .. ")")

		index = 0
		for i = 10, 63, 4 do
			minitree = subtree:add("CAMERA" .. index, buffer())

			capab = buffer(i-2,2)
			first = buffer(i,1):uint()
			second = buffer(i+1,1):uint()

			minitree:add(camera_capabilities, capab):append_text("")

			cam_stat_filtered = bit.band(first, 0x0F)
			if cam_stat_filtered == 0x00 then
				cam_stat_str = "Stato della telecamera non disponibile"
			elseif cam_stat_filtered == 0x01 then
				cam_stat_str = "Telecamera connessa (segnale video presente)"
			elseif cam_stat_filtered == 0x02 then
				cam_stat_str = "Telecamera non connessa (segnale video non presente)"
			elseif cam_stat_filtered == 0x04 then
				cam_stat_str = "Errore nella rilevazione del segnale video"
			end

			cam_monitor_filtered = bit.rshift(first, 4)
			if cam_monitor_filtered == 0x00 then
				cam_monitor_string = "Non disponibile"
			elseif cam_monitor_filtered == 0x01 then
				cam_monitor_string = "Monitor destro"
			elseif cam_monitor_filtered == 0x02 then
				cam_monitor_string = "Monitor centrale"
			elseif cam_monitor_filtered == 0x04 then
				cam_monitor_string = "Monitor sinistro"
			elseif cam_monitor_filtered == 0x08 then
				cam_monitor_string = "Errore"
			end

			cam_roi_filtered = bit.band(second, 0x0F)
			if cam_roi_filtered == 0x00 then
				cam_roi_string = "Non disponibile"
			elseif cam_roi_filtered == 0x01 then
				cam_roi_string = "Full Screen"
			elseif cam_roi_filtered == 0x02 then
				cam_roi_string = "Bottom Half"
			elseif cam_roi_filtered == 0x04 then
				cam_roi_string = "Center Block"
			elseif cam_roi_filtered == 0x08 then
				cam_roi_string = "Top Half"
			end

			cam_polarity_filtered = bit.rshift(second, 4)
			if cam_polarity_filtered == 0x00 then
				cam_polarity_string = "Non disponibile"
			elseif cam_polarity_filtered == 0x01 then
				cam_polarity_string = "IR, WHITE HOT"
			elseif cam_polarity_filtered == 0x02 then
				cam_polarity_string = "IR, BLACK HOT"
			elseif cam_polarity_filtered == 0x04 then
				cam_polarity_string = "DAY ONLY"
			elseif cam_polarity_filtered == 0x08 then
				cam_polarity_string = "NUC Automatico Abilitato"
			end

			minitree:add(camera_status, cam_stat_filtered):append_text(" (" .. cam_stat_str .. ")")
			minitree:add(camera_monitor, cam_monitor_filtered):append_text(" (" .. cam_monitor_string .. ")")
			minitree:add(camera_ROI, cam_roi_filtered):append_text(" (" .. cam_roi_string .. ")")
			minitree:add(camera_Polarity, bit.rshift(second, 4)):append_text(" (" .. cam_polarity_string .. ")")

			index = index + 1
		end

		extended_filtered = buffer(64,1):uint()
		if extended_filtered == 0x00 then
				extended_string = "Marker"
		elseif extended_filtered == 0x01 then
				extended_string = "Drive"
		elseif extended_filtered == 0x10 then
				extended_string = "All"
		elseif extended_filtered == 0x11 then
				extended_string = "Error"
		end

		subtree:add(extended_type, extended_filtered):append_text(" (" .. extended_string .. ")")
		subtree:add(checksum_type, buffer(65,1)):append_text("")
		subtree:add(flagstop_type, buffer(66,1)):append_text("")
	end
end

local tcp_port = DissectorTable.get("tcp.port")
tcp_port:add(80, svs_protocol)