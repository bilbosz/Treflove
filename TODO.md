# Treflove Annotation Fixes - TODO

This file tracks all annotation issues that need to be fixed across the codebase. Check off items as they are completed.

## Task 1: conf.lua
- [ ] **Line 3:** `love.conf(t)` - missing @param annotation for 't' parameter

## Task 2: controls/control.lua
- [ ] **Line 182:** `Control:add_child(child)` - missing @param annotation for 'child' parameter
- [ ] **Line 267:** `Control:set_enabled(value)` - missing @param annotation for 'value' parameter
- [ ] **Line 292:** `Control:set_visible(value)` - missing @param annotation for 'value' parameter

## Task 3: data/asset.lua
- [ ] **Line 8:** `_create_intermediate_dirs(path)` - missing @param annotation

## Task 4: data/asset-manager.lua
- [ ] **Line 13:** `_filter_for_missing_assets(list)` - missing return type annotation
- [ ] **Line 29:** `_remove_server_mount(path)` - missing return type annotation
- [ ] **Line 48:** `_mount_server_assets(src_path, dst_path)` - missing return type annotation
- [ ] **Line 129:** `AssetManager:register_session(session)` - missing @param annotation for 'session' parameter
- [ ] **Line 138:** `AssetManager:unregister_session(session)` - missing @param annotation for 'session' parameter

## Task 5: events/event-manager.lua
- [ ] **Line 4:** `_handle_register(self, listener)` - missing @param annotations
- [ ] **Line 13:** `_handle_unregister(self, listener)` - missing @param annotations
- [ ] **Line 21:** `_is_listener_method_name(method_name)` - missing @param and @return annotations
- [ ] **Line 25:** `EventManager:init(listener_class)` - missing @param annotation
- [ ] **Line 45:** `EventManager:register_listener(listener)` - missing @param annotation
- [ ] **Line 53:** `EventManager:unregister_listener(listener)` - missing @param annotation
- [ ] **Line 74:** `EventManager:invoke_event(method, ...)` - missing @param annotations for method and vararg

## Task 6: events/defer-manager.lua
- [ ] **Line 4:** `_add_defers(self)` - missing @param annotation

## Task 7: events/resize.lua
- [ ] **Line 6:** `ResizeEventListener:on_resize(width, height)` - missing @param annotations
- [ ] **Line 40:** `ResizeManager:set_fullscreen(value)` - missing @param annotation

## Task 8: events/keyboard.lua
- [ ] **Line 6:** `KeyboardEventListener:init(ignore_text_events)` - missing @param annotation
- [ ] **Line 10:** `KeyboardEventListener:on_key_pressed(key)` - missing @param annotation
- [ ] **Line 14:** `KeyboardEventListener:on_key_released(key)` - missing @param annotation
- [ ] **Line 29:** `KeyboardManager:key_pressed(key)` - missing @param annotation
- [ ] **Line 33:** `KeyboardManager:key_released(key)` - missing @param annotation
- [ ] **Line 37:** `KeyboardManager:invoke_event(method, ...)` - missing @param annotations

## Task 9: events/file-drop-event.lua
- [ ] **Line 7:** `FileSystemDropEventListener:init(receive_through)` - missing @param annotation
- [ ] **Line 11:** `FileSystemDropEventListener:on_file_system_drop(x, y, dropped_file)` - missing @param annotations
- [ ] **Line 18:** `_get_listener_list(ctrl, listeners, x, y, list)` - missing @param annotations
- [ ] **Line 34:** `FileSystemDropEventManager:file_drop(dropped_file)` - missing @param annotation
- [ ] **Line 39:** `FileSystemDropEventManager:invoke_event(method, x, y, dropped_file)` - missing @param annotations

## Task 10: events/pointer-event.lua
- [ ] **Line 7:** `PointerEventListener:init(receive_through)` - missing @param annotation
- [ ] **Line 11:** `PointerEventListener:on_pointer_down(x, y, id)` - missing @param annotations
- [ ] **Line 15:** `PointerEventListener:on_pointer_up(x, y, id)` - missing @param annotations
- [ ] **Line 19:** `PointerEventListener:on_pointer_move(x, y, id)` - missing @param annotations
- [ ] **Line 26:** `_get_listener_list(ctrl, listeners, x, y, list)` - missing @param annotations
- [ ] **Line 43:** `PointerEventManager:pointer_down(x, y, id)` - missing @param annotations
- [ ] **Line 48:** `PointerEventManager:pointer_up(x, y, id)` - missing @param annotations
- [ ] **Line 53:** `PointerEventManager:pointer_move(x, y, id)` - missing @param annotations
- [ ] **Line 61:** `PointerEventManager:invoke_event(method, x, y, id)` - missing @param annotations

## Task 11: game/session.lua
- [ ] **Line 12:** `_on_login(self, user)` - missing @param annotations
- [ ] **Line 28:** `_on_logout(self)` - missing @param annotation

## Task 12: game/game-data-rp.lua
- [ ] **Line 8:** `_list_required_assets()` - missing return annotation
- [ ] **Line 19:** `GameDataRp:init(connection)` - missing @param annotation
- [ ] **Line 29:** `GameDataRp:receive_response(response)` - missing @param annotation

## Task 13: game/token/token-panel.lua
- [ ] **Line 11:** `TokenPanel:init(game_screen, width, height)` - missing @param annotations
- [ ] **Line 21:** `TokenPanel:on_resize(w, h)` - missing @param annotations
- [ ] **Line 128-141:** `_get_value_by_key` missing proper return type documentation

## Task 14: game/token/token.lua
- [ ] **Line 13-53:** Multiple local functions missing @param annotations
- [ ] **Line 55:** `Token:init(data, parent)` - missing @param annotations

## Task 15: game/page/selection.lua
- [ ] **Line 10:** `_update_rectangle(self)` - missing @param annotation
- [ ] **Line 19:** `Selection:init(page)` - missing @param annotation

## Task 16: game/page/page.lua
- [ ] **Line 14-31:** `_create_*` methods missing @param annotations
- [ ] **Line 33:** `Page:init(data, game_screen, width, height)` - missing @param annotations
- [ ] **Line 66-159:** Event handler methods missing @param annotations

## Task 17: game/logo.lua
- [ ] **Line 8:** `Logo:init(parent)` - missing @param annotation

## Task 18: game/assets/preview-area/preview-audio-area.lua
- [ ] **Line 10:** `_create_preview(self, _)` - missing @param annotations
- [ ] **Line 22:** `PreviewAudioArea:init(preview_area, love_content)` - missing @param annotations

## Task 19: game/assets/preview-area/preview-area.lua
- [ ] **Line 14-64:** Multiple local functions missing @param annotations
- [ ] **Line 74-107:** Multiple methods missing @param annotations

## Task 20: game/assets/preview-area/preview-image-area.lua
- [ ] **Line 8:** `_create_preview(self, love_content)` - missing @param annotations
- [ ] **Line 20:** `PreviewImageArea:init(preview_area, love_content)` - missing @param annotations

## Task 21: game/assets/assets-panel.lua
- [ ] **Lines 32-204:** Multiple local functions and methods missing @param annotations
- [ ] **Line 207:** `set_file(file)` - missing @param annotation

## Task 22: game/quick-access-panel.lua
- [ ] **Line 8:** `QuickAccessPanel:init(game_screen, width, height)` - missing @param annotations
- [ ] **Line 14:** `add_entry(label, entry)` - missing @param annotations

## Task 23: game/game-screen.lua
- [ ] **Line 13:** `GameScreen:init(data)` - missing @param annotation

## Task 24: login/login.lua
- [ ] **Line 14:** `_get_client_auth(user_name, password)` - missing @param annotations

## Task 25: login/login-rp.lua
- [ ] **Line 7:** `_get_server_auth(user_name, client_auth)` - missing @param annotations
- [ ] **Line 11:** `_find_user_by_client_auth(client_auth)` - missing @param and return annotations
- [ ] **Line 20:** `LoginRp:init(connection, on_login)` - missing @param annotations
- [ ] **Line 25:** `LoginRp:send_response(request)` - missing @param annotation
- [ ] **Line 36:** `LoginRp:receive_response(response)` - missing @param annotation

## Task 26: login/logout-rp.lua
- [ ] **Line 6:** `LogoutRp:init(connection, on_logout)` - missing @param annotations
- [ ] **Line 11-19:** Methods missing @param annotations

## Task 27: login/login-screen.lua
- [ ] **Line 8:** `_login(self)` - missing @param annotation
- [ ] **Line 12:** `LoginScreen:init(login)` - missing @param annotation

## Task 28: networking/connection.lua
- [ ] **Line 115:** `Connection:_handle_response(message)` - return annotation present but could be more specific

## Task 29: panels/notification-panel.lua
- [ ] **Line 12-58:** Multiple methods missing @param annotations

## Task 30: screens/waiting-screen.lua
- [ ] **Line 55:** `WaitingScreen:init(message)` - missing @param annotation

## Task 31: ui/menu/menu-entry.lua
- [ ] **Line 11:** `MenuEntry:create_control(parent)` - @field annotation should be @param

## Task 32: utils/class.lua
- [ ] **Line 5:** `_create_index(self, ...)` - missing @param and return annotations
- [ ] **Line 14:** `_create_bases(self, ...)` - missing @param and return annotations
- [ ] **Line 24:** `_is_instance_of(cls, base)` - missing @param and return annotations

## Task 33: utils/logger.lua
- [ ] **Line 18:** `_is_enabled(name)` - missing @param and return annotations
- [ ] **Line 62-84:** Methods have some annotations but could be more complete

## Task 34: utils/media.lua
- [ ] **Line 15-35:** Local functions missing @param and return annotations

## Task 35: utils/utils.lua
- [ ] **Line 7:** `_draw_aabbs_detail(ctrl)` - missing @param and return annotations
- [ ] **Line 149:** `_long_print(str)` - defined but not annotated
