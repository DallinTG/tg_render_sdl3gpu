package tg_render

import "core:flags"
import sdl "vendor:sdl3"
import "core:log"
import "core:c"
import "core:mem"
import str"core:strings"
import "core:fmt"
import "core:time"
import "core:math"
import "core:path/filepath"
import "core:encoding/json"
import lin"core:math/linalg"
import "base:runtime"
// import hm "handle_map_static_virtual"
import hm "core:container/handle_map"
import steam "steamworks"
import "core:os"

import sc"shader_cross"

import "core:image"
import "core:image/jpeg"
import "core:image/bmp"
import "core:image/png"
import "core:image/tga"



Steam_Info::struct{
	steam_id:u64,
	is_using_steam:bool,
	number_of_current_players: int,
	client:^steam.IClient,
	hd_pipe:steam.HSteamPipe,
	hd_user:steam.HSteamUser,
	user:^steam.IUser,
	i_utils:^steam.IUtils,
	i_matchmaking:^steam.IMatchmaking,
	i_friends:^steam.IFriends,
	user_name:string,
	friends:Player_Groop,
	steam_lobby:Player_Groop,
	networking_identity:steam.SteamNetworkingIdentity,
	i_networking_messages:^steam.INetworkingMessages,
}
MAX_PLAYERS_IN_LOBBY::10


Player_Platform_Steam::struct{
	status:steam.EPersonaState,
	cs_id:steam.CSteamID,
	net_id:steam.SteamNetworkingIdentity,
	game:steam.FriendGameInfo,
}



init_steam::proc(){
	err_msg: steam.SteamErrMsg
	// if err := steam.InitEx(&err_msg); err != .OK {

	if steam.RestartAppIfNecessary(steam.uAppIdInvalid) {
		log.log(.Info,"Launching app through steam...","\n")
		return
	}
	if err := steam.InitFlat(&err_msg); err != .OK {
		log.log(.Info,"steam.InitFlat failed with code '{}' and message \"{}\"", err, transmute(cstring)&err_msg[0],"\n")
		return
	}

	// s.steam.client = steam.Client()

	s.steam.client =  steam.SteamClient()
	s.steam.user = steam.User()
	// s.steam.hd_user = steam.User_GetHSteamUser(s.steam.user)
	// s.steam.hd_pipe = steam.GetHSteamPipe()

	steam.Client_SetWarningMessageHook(s.steam.client, steam_debug_text_hook)
	steam.ManualDispatch_Init()

	if !steam.User_BLoggedOn(steam.User()) {
		panic("User isn't logged in.")
	} else {
		log.log(.Info,"USER IS LOGGED IN")
	}
	s.steam.i_utils= steam.SteamUtils_v010()
	s.steam.steam_id = steam.User_GetSteamID(s.steam.user)
	update_steam_friend_info()
	s.steam.i_networking_messages = steam.NetworkingMessages_SteamAPI()
	s.steam.i_matchmaking = steam.SteamMatchmaking_v009()
	steam.NetworkingIdentity_SetSteamID(&s.steam.networking_identity, s.steam.steam_id)
	create_steame_lobby()
	s.steam.is_using_steam = true
	
}

cleane_up_steam::proc(){
	if s.steam.is_using_steam != true {return}
	delete_player_groop(&s.steam.friends)
	lobby:=get_steam_lobby()
	if lobby != nil{
		delete_player_groop(&s.steam.steam_lobby)
	}
	steam.Shutdown()
}

update_steam_friend_info::proc(){
	if s.steam.is_using_steam != true {return}
	s.steam.i_friends=steam.SteamFriends_v017()
	i_frd:=s.steam.i_friends
	s.steam.user_name=cast(string)steam.Friends_GetPersonaName(i_frd) //→ your Steam display name
	s.steam.friends.flags =cast(u64)steam.EFriendFlags.Immediate
	update_player_groop(&s.steam.friends)
}

update_steam_lobby_data::proc(lobby_id:u64){
	if s.steam.is_using_steam != true {return}
	groop := get_steam_lobby()
	if groop == nil{return}
	
	groop.groop_id = lobby_id
	groop.type = .lobby_list
	groop.groop_endpoint = steam.SteamNetworkingIdentity{}
	log.log(.Info,"updateing ",lobby_id,"\n")
	#partial switch &ep in &groop.groop_endpoint {
		case steam.SteamNetworkingIdentity:
		steam.NetworkingIdentity_SetSteamID(&ep,groop.groop_owner_id)	
	}
	update_player_groop(groop)
	dnwi:=get_defalt_networking_instance()
	if dnwi != nil{
		if dnwi.type == .nil ||dnwi.type == .client{
			join_server(server_endpoint = &groop.groop_endpoint, net_inst=dnwi)
		} 
	}

}


get_steam_lobby::proc()->(groop:^Player_Groop){
	if s.steam.is_using_steam != true {return}
	groop = &s.steam.steam_lobby
	return
}

_update_steam_player_groop_count::proc(groop:^Player_Groop){
	if groop == nil {return}
	switch groop.type{
		case .friends_list:
			groop.count += steam.Friends_GetFriendCount(s.steam.i_friends ,cast(i32)groop.flags) //→ number of friends
		case .lobby_list:
			groop.count += steam.Matchmaking_GetNumLobbyMembers(s.steam.i_matchmaking ,groop.groop_id)
		case .server_list:
	}
}

// this must be called by update_player_groop()
_update_steam_player_groop::proc(groop:^Player_Groop){
	if groop == nil {return}
	if s.steam.is_using_steam != true {return}
	i_friends:=s.steam.i_friends
	
	switch groop.type{
		case .friends_list:
		case .lobby_list:
			groop.groop_owner_id=steam.Matchmaking_GetLobbyOwner(s.steam.i_matchmaking,groop.groop_id)
			temp_name:=steam.Friends_GetFriendPersonaName(s.steam.i_friends,groop.groop_owner_id)
			groop.groop_owner_name=str.clone_from_cstring(temp_name)
		case .server_list:
	}

	for i in 0..<groop.count{
	
		plat:Player_Platform_Steam
		info:Player_Info
		endpoint:Endpoint

		switch groop.type{
			case .friends_list:
				plat.cs_id = steam.Friends_GetFriendByIndex(i_friends, i, cast(i32)groop.flags)
			case .lobby_list:
				plat.cs_id = steam.Matchmaking_GetLobbyMemberByIndex(s.steam.i_matchmaking, groop.groop_id, i)
			case .server_list:
		}

		info.name = str.clone_from_cstring(steam.Friends_GetFriendPersonaName(i_friends,plat.cs_id))
		steam.Friends_GetFriendGamePlayed(i_friends,plat.cs_id,&plat.game)
		plat.status = steam.Friends_GetFriendPersonaState(i_friends,plat.cs_id) //→ online/offline/busy/etc
		info.status_string = status_to_string(plat.status)
		info.lev = cast(int)steam.Friends_GetFriendSteamLevel(i_friends,plat.cs_id)
		update_steam_prof_pic(i_friends,&info, &plat)
	
		append(&groop.player,Player{platform = plat, info = info, endpoint = endpoint})
	}
}

update_steam_prof_pic::proc(i_friends: ^steam.IFriends,info: ^Player_Info, plat:^Player_Platform_Steam){
		if s.gpu_device != nil{
			info.l_player_icon_id = steam.Friends_GetLargeFriendAvatar(i_friends, plat.cs_id)
			w,h:u32
			steam.Utils_GetImageSize(
				s.steam.i_utils,
				info.l_player_icon_id,
				&w,
				&h,
			)
			if w != 0 && h != 0{
				buffer := make([]u8, w * h * 4)
				ok:=steam.Utils_GetImageRGBA(
					s.steam.i_utils,
					info.l_player_icon_id,
					raw_data(buffer),
					cast(i32)len(buffer),
				)
				if ok{
					raw_buff:=mem.slice_data_cast([][4]u8,buffer)
					// player.l_player_icon_gpu_id = load_texture_from_bytes_raw(buffer,cast(int)w,cast(int)h,.R8G8B8A8_UNORM)
					img,image_ok:=image.pixels_to_image(raw_buff,cast(int)w,cast(int)h)
					if image_ok{

						info.l_player_icon_gpu_hd,info.l_player_icon_gpu_id = reg_texture_from_bits(&img,[2]string{"steam_player_icon_l",info.name})
					}
				}
				delete(buffer)
			}
		}
}



steam_debug_text_hook :: proc "c" (severity: c.int, debugText: cstring) {
	if s.steam.is_using_steam != true {return}
	// if you're running in the debugger, only warnings (nSeverity >= 1) will be sent
	// if you add -debug_steamworksapi to the command-line, a lot of extra informational messages will also be sent
	runtime.print_string(string(debugText))

	if severity >= 1 {
		runtime.debug_trap()
	}
}
	
run_steam_callbacks :: proc() {
	if s.steam.is_using_steam != true {return}
    temp_mem := make([dynamic]byte, context.temp_allocator)

    steam_pipe := steam.GetHSteamPipe()
    steam.ManualDispatch_RunFrame(steam_pipe)
    callback: steam.CallbackMsg
    // enabled := steam.SteamUtils().IsOverlayEnabled()
    for steam.ManualDispatch_GetNextCallback(steam_pipe, &callback) {
        // Check for dispatching API call results
        if callback.iCallback == .SteamAPICallCompleted {
            call_completed := transmute(^steam.SteamAPICallCompleted)callback.pubParam
            resize(&temp_mem, int(callback.cubParam))
            if temp_call_res, ok := mem.alloc(int(callback.cubParam), allocator = context.temp_allocator); ok == nil {
                bFailed: bool
                if steam.ManualDispatch_GetAPICallResult(steam_pipe, call_completed.hAsyncCall, temp_call_res, callback.cubParam, callback.iCallback, &bFailed) {
                    // Dispatch the call result to the registered handler(s) for the
                    // call identified by call_completed->m_hAsyncCall
                    // if call_completed.iCallback == .NumberOfCurrentPlayers {
                    //     onGetNumberOfCurrentPlayers(transmute(^steam.NumberOfCurrentPlayers)temp_call_res, bFailed)
                    // }
                    #partial switch call_completed.iCallback{
                    case .NumberOfCurrentPlayers:
                	log.log(.Info,"NumberOfCurrentPlayers\n")
                      onGetNumberOfCurrentPlayers(transmute(^steam.NumberOfCurrentPlayers)temp_call_res, bFailed)
                    case .GameLobbyJoinRequested:
                    log.log(.Info,"GameLobbyJoinRequested\n")
                    case .LobbyInvite:
                    log.log(.Info,"LobbyInvite\n")
                    case .LobbyEnter:
                    log.log(.Info,"LobbyEnter\n")
                    case .LobbyDataUpdate:
                    log.log(.Info,"LobbyDataUpdate\n")
                    case .LobbyChatUpdate:
                    log.log(.Info,"LobbyChatUpdatee\n")
                    case .LobbyChatMsg:
                    log.log(.Info,"LobbyChatMsg\n")
                    case .LobbyGameCreated:
                    log.log(.Info,"LobbyGameCreated\n")
                    case .LobbyMatchList:
                    log.log(.Info,"LobbyMatchList\n")
                    case .LobbyKicked:
                    log.log(.Info,"LobbyKicked\n")
                    case .LobbyCreated:
                    log.log(.Info,"LobbyCreated\n")
                   
	
                    }
                }
            }

        } else {
            // Look at callback.m_iCallback to see what kind of callback it is,
            // and dispatch to appropriate handler(s)
            #partial switch callback.iCallback{
            case .GameOverlayActivated:
                log.log(.Info,"GameOverlayActivated")
                onGameOverlayActivated(transmute(^steam.GameOverlayActivated)callback.pubParam)

			case .LobbyCreated:
				log.log(.Info,"LobbyCreated_fin\n")
				temp:=transmute(^steam.LobbyCreated)callback.pubParam
				if temp.eResult == .OK{
					update_steam_lobby_data(temp.ulSteamIDLobby)
				}else{
					log.log(.Info,"Lobby Creation failed",temp.eResult,"\n"  )
					send_simp_error_notification(&s.ui.notifications, "Lobby Creation failed")
				}
			case .GameLobbyJoinRequested:
				log.log(.Info,"GameLobbyJoinRequested_fin\n")
				temp:=transmute(^steam.GameLobbyJoinRequested)callback.pubParam
				steam_join_lobby(temp.steamIDLobby)
				update_steam_friend_info()
			case .LobbyInvite:
				temp:=transmute(^steam.LobbyInvite)callback.pubParam
				send_accept_invite_to_game_notification(&s.ui.notifications,"you got invite to a game",lobby_id = temp.ulSteamIDLobby)
				update_steam_friend_info()
				log.log(.Info,"LobbyInvite_fin\n")
			case .LobbyEnter:
				temp:=transmute(^steam.LobbyEnter)callback.pubParam
				err:=cast(steam.EChatRoomEnterResponse)temp.EChatRoomEnterResponse
				log.log(.Info,"LobbyEnter_fin",err,"\n")
				if err == .Success {
					groop:=get_steam_lobby()
					if groop != nil{
						// update_steam_lobby_data(temp.ulSteamIDLobby)
						if groop.groop_id != temp.ulSteamIDLobby{
							log.log(.Info,"leaving lobby ",groop.groop_id,"\n")
							steam.Matchmaking_LeaveLobby(s.steam.i_matchmaking,groop.groop_id)
						}
						update_steam_lobby_data(temp.ulSteamIDLobby)
						update_steam_friend_info()
					}
				}else{
					log.log(.Info,"Lobby Enter failed",err,"\n"  )
					send_simp_error_notification(&s.ui.notifications, "Lobby Enter failed")
				}
			case .LobbyDataUpdate:
				temp:=transmute(^steam.LobbyDataUpdate)callback.pubParam
				log.log(.Info,"LobbyDataUpdate_fin",temp.ulSteamIDLobby,"\n")
				update_steam_lobby_data(temp.ulSteamIDLobby)
				update_steam_friend_info()

			case .LobbyChatUpdate:
				log.log(.Info,"LobbyChatUpdatee_fin\n")
				temp:=transmute(^steam.LobbyChatUpdate)callback.pubParam
				update_steam_lobby_data(temp.ulSteamIDLobby)
				update_steam_friend_info()
			case .LobbyChatMsg:
				log.log(.Info,"LobbyChatMsg_fin\n")
			case .LobbyGameCreated:
				log.log(.Info,"LobbyGameCreated_fin\n")
			case .LobbyMatchList:
				log.log(.Info,"LobbyMatchList_fin\n")
				temp:=transmute(^steam.LobbyMatchList)callback.pubParam
				for index in  0..<temp.nLobbiesMatching{
					loby_id:=steam.Matchmaking_GetLobbyByIndex(s.steam.i_matchmaking,cast(i32)index)
					log.log(.Info,loby_id,"\n")
					max_members := steam.Matchmaking_GetLobbyMemberLimit(s.steam.i_matchmaking,loby_id,)
					// log.log(.Info,"max_members",max_members,"\n")
					owner := steam.Matchmaking_GetLobbyOwner(s.steam.i_matchmaking,loby_id,)
					// log.log(.Info,"owner",owner ,"\n")
					loby_name := steam.Matchmaking_GetLobbyData(s.steam.i_matchmaking,loby_id,"name")
					// log.log(.Info,"loby_name ",loby_name  ,"\n")
	
					num_lobby_members:=steam.Matchmaking_GetNumLobbyMembers(s.steam.i_matchmaking,loby_id)
					// log.log(.Info,"num_lobby_members",num_lobby_members ,"\n")
					for member_index in  0..<num_lobby_members{
						// steam_user_id:=steam.Matchmaking_GetLobbyMemberByIndex(s.steam.i_matchmaking,loby_id,member_index)
						// log.log(.Info,"steam_user_id",steam_user_id,"\n")
					}
					lobby_data_count:=steam.Matchmaking_GetLobbyDataCount(s.steam.i_matchmaking,loby_id)
					// log.log(.Info,"lobby_data_count",lobby_data_count ,"\n")
					
					for data_index in  0..<lobby_data_count{
						pchKey:[255]u8
						cchKeyBufferSize: i32=255
						pchValue:[8192]u8
						cchValueBufferSize: i32=8192
						steam.Matchmaking_GetLobbyDataByIndex(s.steam.i_matchmaking,loby_id,data_index,raw_data(&pchKey),cchKeyBufferSize,raw_data(&pchValue),cchValueBufferSize)
					}
				}
				log.log(.Info,temp.nLobbiesMatching,"\n")
			case .LobbyKicked:
				log.log(.Info,"LobbyKicked_fin\n")
			case .PersonaStateChange:
				update_steam_friend_info()
			case .SteamNetworkingMessagesSessionRequest:
				temp:=transmute(^steam.SteamNetworkingMessagesSessionRequest)callback.pubParam
				log.log(.Info,"SteamNetworkingMessagesSessionRequest",temp.identityRemote,"\n")
				steam.NetworkingMessages_AcceptSessionWithUser(s.steam.i_networking_messages,&temp.identityRemote)

			case:
				log.log(.Info,callback.iCallback,"\n")
			}
			

			// if callback.iCallback == .GameOverlayActivated {
			//     log.log(.Info,"GameOverlayActivated")
			//     onGameOverlayActivated(transmute(^steam.GameOverlayActivated)callback.pubParam)
			// }
		}
		// enabled :=steam.Utils_IsOverlayEnabled(steam.Utils() )
		steam.ManualDispatch_FreeLastCallback(steam_pipe)
	}
}
onGameOverlayActivated :: proc(data: ^steam.GameOverlayActivated) {
    log.log(.Info,"Is overlay active =", data.bActive)
}

onGetNumberOfCurrentPlayers :: proc(data: ^steam.NumberOfCurrentPlayers, ioFailure: bool) {
    log.log(.Info,"[get_number_of_current_players] success:", data.bSuccess)
    if ioFailure || !bool(data.bSuccess) {
        log.log(.Info,"get_number_of_current_players failed.")
        return
    }

    log.log(.Info,"[get_number_of_current_players] Number of players currently playing:", data.cPlayers)
    s.steam.number_of_current_players = int(data.cPlayers)
}

get_number_of_current_players :: proc() {
	if s.steam.is_using_steam != true {return}
	log.log(.Info,"[get_number_of_current_players] Getting number of current players.")
	hSteamApiCall := steam.UserStats_GetNumberOfCurrentPlayers(steam.UserStats())
}


status_to_string::proc(stat:steam.EPersonaState)->(new_string:string){
	switch stat{
	case.Offline:
	new_string = "Offline"
	case.Online:
	new_string = "Online"
	case.Busy:
	new_string = "Busy"
	case.Away:
	new_string = "Away"
	case.Snooze:
	new_string = "Snooze"
	case.LookingToTrade:
	new_string = "Looking To Trade"
	case.LookingToPlay:
	new_string = "Looking To Play"
	case.Invisible:
	new_string = "Invisible"
	case.Max:
	new_string = "Max"
	}
	return
}



create_steame_lobby::proc(){
	if s.steam.is_using_steam != true {return}
	steam.Matchmaking_CreateLobby(s.steam.i_matchmaking,.FriendsOnly,10)
}

steam_invite_player_to_lobby::proc(player_id:steam.CSteamID){
	if s.steam.is_using_steam != true {return}
	groop:=get_steam_lobby()
	if groop == nil{return}
	steam.Matchmaking_InviteUserToLobby(s.steam.i_matchmaking,groop.groop_id,player_id)
	
}

steam_join_lobby::proc(lobby_id:steam.CSteamID){
	if s.steam.is_using_steam != true {return}
	steam.Matchmaking_JoinLobby(s.steam.i_matchmaking, lobby_id)
}
