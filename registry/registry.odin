package registry

import hm "core:container/handle_map"
import "base:runtime"
import "base:builtin"
import "base:intrinsics"

Reg_ID::[2]u32 // defalt reg id
Registry::struct($T: typeid, $Handle_Type: typeid)
	where
		intrinsics.type_has_field(T, "reg_id")
{
	list:map[u64]Handle_Type,
	data:hm.Dynamic_Handle_Map(T,Handle_Type),
}


// create::proc(){

// }

destroy::proc(r: ^$D/Registry($T, $Handle_Type),){
	delete(r.list)
	hm.dynamic_destroy(&r.data)
}

add::proc(r: ^$D/Registry($T, $Handle_Type), item: T,id:Reg_ID, loc := #caller_location) -> (handle: Handle_Type, err: runtime.Allocator_Error) #optional_allocator_error {
	ok := transmute(u64)id in r.list
	if ok{
		handle=r.list[transmute(u64)id]
		reg_data:=hm.get(&r.data,handle)
		reg_data^ = item
	}else{
		handle=hm.add(&r.data,item)
		r.list[transmute(u64)id] = handle
	}
	// r.list[transmute(u64)id] = handle
	return
}

remove_by_id::proc(r: ^$D/Registry($T, $Handle_Type), id:Reg_ID, loc := #caller_location) -> (found: bool, err: runtime.Allocator_Error) {
	hd:=r.list[transmute(u64)id]
	delete_key(r.list,transmute(u64)id)
	found,err=hm.remove(r,hd)
	return
}
remove_by_hd::proc(r: ^$D/Registry($T, $Handle_Type), hd:Handle_Type, loc := #caller_location) -> (found: bool, err: runtime.Allocator_Error) {
	// hd:=r.list[transmute(u64)id]
	reg_data,ok:=hm.get(r,hd)
	if !ok {return {false, .non}}
	delete_key(r.list,transmute(u64)id)
	found,err=hm.remove(r,hd)
	return
}
has_id::proc(r: ^$D/Registry($T, $Handle_Type), id:Reg_ID, loc := #caller_location) -> (has:bool) {
	has = transmute(u64)id in r.list
	return
}
get_hd::proc(r: ^$D/Registry($T, $Handle_Type), id:Reg_ID, loc := #caller_location) -> (hd:Handle_Type) {
	ok := transmute(u64)id in r.list
	if ok{
		hd=r.list[transmute(u64)id]
		return
	}
	hd={0,0}
	return
}

get::proc(r: ^$D/Registry($T, $Handle_Type), hd:Handle_Type, loc := #caller_location) -> (data:^T) {
	data=hm.dynamic_get(&r.data,hd)
	return
}

//warning ths is far slower than just get()
get_by_id::proc(r: ^$D/Registry($T, $Handle_Type), id:Reg_ID, loc := #caller_location) -> (data:^T) {
	return get(r,get_hd(r,id))
}
