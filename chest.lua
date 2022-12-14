exchange.chest = {}
exchange.chest.formspec = {
	main = "size[8,9]"..
		"list[current_name;pl1;0,0;3,4;]"..
		"list[current_name;pl2;5,0;3,4;]"..
		"list[current_player;main;0,5;8,4;]",
	pl1 = {
		start = "button[3,1;1,1;pl1_start;Start]",
		player = function(name) return "label[3,0;"..name.."]" end,
		accept1 = "button[3,1;1,1;pl1_accept1;Confirm]"..
				"button[3,2;1,1;pl1_cancel;Cancel]",
		accept2 = "button[3,1;1,1;pl1_accept2;Exchange]"..
				"button[3,2;1,1;pl1_cancel;Cancel]",
	},
	pl2 = {
		start = "button[4,1;1,1;pl2_start;Start]",
		player = function(name) return "label[4,0;"..name.."]" end,
		accept1 = "button[4,1;1,1;pl2_accept1;Confirm]"..
				"button[4,2;1,1;pl2_cancel;Cancel]",
		accept2 = "button[4,1;1,1;pl2_accept2;Exchange]"..
				"button[4,2;1,1;pl2_cancel;Cancel]",
	},
}

exchange.chest.check_privilege = function(listname,playername,meta)
	if listname == "pl1" then
		if playername ~= meta:get_string("pl1") then
			return false
		elseif meta:get_int("pl1step") ~= 1 then
			return false
		end
	end
	if listname == "pl2" then
		if playername ~= meta:get_string("pl2") then
			return false
		elseif meta:get_int("pl2step") ~= 1 then
			return false
		end
	end
	return true
end

exchange.chest.update_formspec = function(meta)
	formspec = exchange.chest.formspec.main
	pl_formspec = function (n)
		if meta:get_int(n.."step")==0 then
			formspec = formspec .. exchange.chest.formspec[n].start
		else
			formspec = formspec .. exchange.chest.formspec[n].player(meta:get_string(n))
			if meta:get_int(n.."step") == 1 then
				formspec = formspec .. exchange.chest.formspec[n].accept1
			elseif meta:get_int(n.."step") == 2 then
				formspec = formspec .. exchange.chest.formspec[n].accept2
			end
		end
	end
	pl_formspec("pl1") pl_formspec("pl2")
	meta:set_string("formspec",formspec)
end

exchange.chest.give_inventory = function(inv,list,playername)
	player = minetest.env:get_player_by_name(playername)
	if player then
		for k,v in ipairs(inv:get_list(list)) do
			player:get_inventory():add_item("main",v)
			inv:remove_item(list,v)
		end
	end
end

exchange.chest.cancel = function(meta)
	exchange.chest.give_inventory(meta:get_inventory(),"pl1",meta:get_string("pl1"))
	exchange.chest.give_inventory(meta:get_inventory(),"pl2",meta:get_string("pl2"))
	meta:set_string("pl1","")
	meta:set_string("pl2","")
	meta:set_int("pl1step",0)
	meta:set_int("pl2step",0)
end

exchange.chest.exchange = function(meta)
	exchange.chest.give_inventory(meta:get_inventory(),"pl1",meta:get_string("pl2"))
	exchange.chest.give_inventory(meta:get_inventory(),"pl2",meta:get_string("pl1"))
	meta:set_string("pl1","")
	meta:set_string("pl2","")
	meta:set_int("pl1step",0)
	meta:set_int("pl2step",0)
end

minetest.register_node("exchange:chest", {
	description = "Exchange chest",
	tiles = {"default_chest_top.png^exchange_chest_top.png", "default_chest_top.png^default_chest_top.png", "default_chest_lock.png^exchange_chest_side.png"},
	groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2},
	sounds = default.node_sound_wood_defaults(),
	on_construct = function(pos)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("infotext", "Exchange chest")
		meta:set_string("pl1","")
		meta:set_string("pl2","")
		exchange.chest.update_formspec(meta)
		local inv = meta:get_inventory()
		inv:set_size("pl1", 3*4)
		inv:set_size("pl2", 3*4)
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.env:get_meta(pos)
		pl_receive_fields = function(n)
			if fields[n.."_start"] and meta:get_string(n) == "" then
				meta:set_string(n,sender:get_player_name())
			end
			if meta:get_string(n) == "" then
				meta:set_int(n.."step",0)
			elseif meta:get_int(n.."step")==0 then
				meta:set_int(n.."step",1)
			end
			if sender:get_player_name() == meta:get_string(n) then
				if meta:get_int(n.."step")==1 and fields[n.."_accept1"] then
					meta:set_int(n.."step",2)
				end
				if meta:get_int(n.."step")==2 and fields[n.."_accept2"] then
					meta:set_int(n.."step",3)
					if n == "pl1" and meta:get_int("pl2step") == 3 then exchange.chest.exchange(meta) end
					if n == "pl2" and meta:get_int("pl1step") == 3 then exchange.chest.exchange(meta) end
				end
				if fields[n.."_cancel"] then exchange.chest.cancel(meta) end
			end
		end
		pl_receive_fields("pl1") pl_receive_fields("pl2")
		-- End
		exchange.chest.update_formspec(meta)
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		local meta = minetest.env:get_meta(pos)
		if not exchange.chest.check_privilege(from_list,player:get_player_name(),meta) then return 0 end
		if not exchange.chest.check_privilege(to_list,player:get_player_name(),meta) then return 0 end
		return count
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local meta = minetest.env:get_meta(pos)
		if not exchange.chest.check_privilege(listname,player:get_player_name(),meta) then return 0 end
		return stack:get_count()
	end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		local meta = minetest.env:get_meta(pos)
		if not exchange.chest.check_privilege(listname,player:get_player_name(),meta) then return 0 end
		return stack:get_count()
	end,
})

minetest.register_craft({
	output = 'exchange:chest',
	recipe = {
		{"group:wood","default:steel_ingot","group:wood"},
		{"group:wood","default:steel_ingot","group:wood"},
		{"group:wood","group:wood","group:wood"},
	}
})

