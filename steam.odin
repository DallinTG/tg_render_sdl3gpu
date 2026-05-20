package tg_render

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
import hm "handle_map_static_virtual"
import steam "steamworks"
import "core:os"

import sc"shader_cross"

import "core:image"
import "core:image/jpeg"
import "core:image/bmp"
import "core:image/png"
import "core:image/tga"


Steam_Info::struct{
	is_using_steam:bool,
	number_of_current_players: int,
	client:^steam.IClient,
	hd_pipe:steam.HSteamPipe,
	hd_user:steam.HSteamUser,
	user:^steam.IUser,
	i_friends:^steam.IFriends,
	user_name:string,
	friends:Steam_Player_Groop,
}

Steam_Player::struct{
	name:string,
	status:steam.EPersonaState,
	cs_id:steam.CSteamID,
	game:steam.FriendGameInfo,
}
Steam_Player_Groop::struct{
	filter:steam.EFriendFlags,
	count:i32,
	player:[dynamic]Steam_Player,
}

init_steam::proc(){
	if steam.RestartAppIfNecessary(steam.uAppIdInvalid) {
		fmt.println("Launching app through steam...")
		return
	}
	s.steam.is_using_steam = true


	err_msg: steam.SteamErrMsg
	// if err := steam.InitEx(&err_msg); err != .OK {

	if err := steam.InitFlat(&err_msg); err != .OK {
		fmt.printfln("steam.InitFlat failed with code '{}' and message \"{}\"", err, transmute(cstring)&err_msg[0])
		panic("Steam Init failed. Make sure Steam is running.")
	}
	// s.steam.client = steam.Client()

	s.steam.client =  steam.SteamClient()
	// s.steam.user = steam.User()
	// s.steam.hd_user = steam.User_GetHSteamUser(s.steam.user)
	// s.steam.hd_pipe = steam.GetHSteamPipe()

	steam.Client_SetWarningMessageHook(s.steam.client, steam_debug_text_hook)
	steam.ManualDispatch_Init()

	if !steam.User_BLoggedOn(steam.User()) {
		panic("User isn't logged in.")
	} else {
		fmt.println("USER IS LOGGED IN")
	}

	update_steam_friend_info()
}
update_steam_friend_info::proc(){
	s.steam.i_friends=steam.SteamFriends_v017()
	i_frd:=s.steam.i_friends
	s.steam.user_name=cast(string)steam.Friends_GetPersonaName(i_frd) //→ your Steam display name
	s.steam.friends.filter = .All
	update_steame_player_groop(&s.steam.friends,i_frd)
}
update_steame_player_groop::proc(groop:^Steam_Player_Groop,i_frd:^steam.IFriends){
	groop.count = steam.Friends_GetFriendCount(i_frd,cast(i32)groop.filter) //→ number of friends
	clear(&groop.player)
	resize_dynamic_array(&groop.player,groop.count+1)
	for i in 0..=groop.count{
		fmt.print(i,"\n")
		
		groop.player[i].cs_id = steam.Friends_GetFriendByIndex(i_frd,i,cast(i32)groop.filter) //→ get each friend's SteamID
		fmt.print(groop.player[i].cs_id,"\n")
		groop.player[i].name = cast(string)steam.Friends_GetFriendPersonaName(i_frd,groop.player[i].cs_id)
		fmt.print(groop.player[i].name,"\n")
		game:=steam.FriendGameInfo{}
		steam.Friends_GetFriendGamePlayed(i_frd,groop.player[i].cs_id,&groop.player[i].game)
		fmt.print(game,"\n")
		groop.player[i].status = steam.Friends_GetFriendPersonaState(i_frd,groop.player[i].cs_id) //→ online/offline/busy/etc
		fmt.print(groop.player[i].status,"\n")
	}
}



steam_debug_text_hook :: proc "c" (severity: c.int, debugText: cstring) {
	// if you're running in the debugger, only warnings (nSeverity >= 1) will be sent
	// if you add -debug_steamworksapi to the command-line, a lot of extra informational messages will also be sent
	runtime.print_string(string(debugText))

	if severity >= 1 {
		runtime.debug_trap()
	}
}
	
run_steam_callbacks :: proc() {
    temp_mem := make([dynamic]byte, context.temp_allocator)

    steam_pipe := steam.GetHSteamPipe()
    steam.ManualDispatch_RunFrame(steam_pipe)
    callback: steam.CallbackMsg

    // enabled := steam.SteamUtils().IsOverlayEnabled()
    for steam.ManualDispatch_GetNextCallback(steam_pipe, &callback) {
        // Check for dispatching API call results
        fmt.print("Callback: ",callback,callback.iCallback,"\n")
        if callback.iCallback == .SteamAPICallCompleted {
            // fmt.println("CallResult: ", callback)

            call_completed := transmute(^steam.SteamAPICallCompleted)callback.pubParam
            resize(&temp_mem, int(callback.cubParam))
            if temp_call_res, ok := mem.alloc(int(callback.cubParam), allocator = context.temp_allocator); ok == nil {
                bFailed: bool
                if steam.ManualDispatch_GetAPICallResult(steam_pipe, call_completed.hAsyncCall, temp_call_res, callback.cubParam, callback.iCallback, &bFailed) {
                    // Dispatch the call result to the registered handler(s) for the
                    // call identified by call_completed->m_hAsyncCall
                    fmt.println("call_completed", call_completed)
                    // if call_completed.iCallback == .NumberOfCurrentPlayers {
                    // 	fmt.print("waffles 5\n")
                    //     onGetNumberOfCurrentPlayers(transmute(^steam.NumberOfCurrentPlayers)temp_call_res, bFailed)
                    // }
                    #partial switch call_completed.iCallback{
                    case .NumberOfCurrentPlayers:
                    	fmt.print("waffles 5\n")
                        onGetNumberOfCurrentPlayers(transmute(^steam.NumberOfCurrentPlayers)temp_call_res, bFailed)
                    }
                }
            }

        } else {
            // Look at callback.m_iCallback to see what kind of callback it is,
            // and dispatch to appropriate handler(s)
            // fmt.println("Callback: ", callback)
            fmt.print("waffles\n")
            #partial switch callback.iCallback{
            case .GameOverlayActivated:
                fmt.println("GameOverlayActivated")
                onGameOverlayActivated(transmute(^steam.GameOverlayActivated)callback.pubParam)
            }
            

            // if callback.iCallback == .GameOverlayActivated {
            //     fmt.println("GameOverlayActivated")
            //     onGameOverlayActivated(transmute(^steam.GameOverlayActivated)callback.pubParam)
            // }
        }
        // enabled :=steam.Utils_IsOverlayEnabled(steam.Utils() )
    	// fmt.print("steam overlay is enabbled",enabled,"\n")
        steam.ManualDispatch_FreeLastCallback(steam_pipe)
    }
}
onGameOverlayActivated :: proc(data: ^steam.GameOverlayActivated) {
    fmt.println("Is overlay active =", data.bActive)
}

onGetNumberOfCurrentPlayers :: proc(data: ^steam.NumberOfCurrentPlayers, ioFailure: bool) {
    fmt.println("[get_number_of_current_players] success:", data.bSuccess)
    if ioFailure || !bool(data.bSuccess) {
        fmt.println("get_number_of_current_players failed.")
        return
    }

    fmt.println("[get_number_of_current_players] Number of players currently playing:", data.cPlayers)
    s.steam.number_of_current_players = int(data.cPlayers)
}

get_number_of_current_players :: proc() {
    fmt.println("[get_number_of_current_players] Getting number of current players.")
    hSteamApiCall := steam.UserStats_GetNumberOfCurrentPlayers(steam.UserStats())
}
