use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    App, AppHandle, Manager,
};

pub fn setup_tray(app: &mut App) -> tauri::Result<()> {
    let open_dashboard =
        MenuItem::with_id(app, "open_dashboard", "Open Dashboard", true, None::<&str>)?;
    let refresh = MenuItem::with_id(app, "refresh", "Refresh", true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", "Quit TokenTrack", true, None::<&str>)?;

    let menu = Menu::with_items(app, &[&open_dashboard, &refresh, &quit])?;

    TrayIconBuilder::with_id("main-tray")
        .icon(app.default_window_icon().unwrap().clone())
        .icon_as_template(true)
        .tooltip("TokenTrack")
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id.as_ref() {
            "open_dashboard" => show_dashboard(app),
            "refresh" => {
                let app = app.clone();
                tauri::async_runtime::spawn(async move {
                    let cache = app.state::<crate::state::SharedCache>();
                    let _ = crate::state::refresh_cache(&cache).await;
                });
            }
            "quit" => app.exit(0),
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                position,
                rect,
                ..
            } = event
            {
                let _ = (position, rect);
                toggle_popover(tray.app_handle());
            }
        })
        .build(app)?;

    Ok(())
}

pub fn show_dashboard(app: &AppHandle) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.show();
        let _ = window.set_focus();
    }
}

pub fn toggle_popover(app: &AppHandle) {
    if let Some(window) = app.get_webview_window("tray-popover") {
        if window.is_visible().unwrap_or(false) {
            let _ = window.hide();
        } else {
            position_popover_near_tray(app, &window);
            let _ = window.show();
            let _ = window.set_focus();
        }
    }
}

fn position_popover_near_tray(app: &AppHandle, window: &tauri::WebviewWindow) {
    // Get tray icon rect from the tray icon itself
    let Some(tray) = app.tray_by_id("main-tray") else {
        return;
    };
    let Ok(Some(rect)) = tray.rect() else { return };

    let win_size = window
        .outer_size()
        .unwrap_or(tauri::PhysicalSize::new(380u32, 520u32));

    // Extract physical position — convert from logical if needed using scale factor 1.0
    let scale = window.scale_factor().unwrap_or(1.0);
    let pos = rect.position.to_physical::<i32>(scale);
    let size = rect.size.to_physical::<u32>(scale);

    // Place popover below the menu bar icon, centered horizontally on the tray icon
    let x = pos.x + size.width as i32 / 2 - win_size.width as i32 / 2;
    let y = pos.y + size.height as i32;

    // Clamp to screen bounds if we can get them
    if let Ok(Some(monitor)) = window.primary_monitor() {
        let screen_w = monitor.size().width as i32;
        let x = x.clamp(0, (screen_w - win_size.width as i32).max(0));
        let _ = window.set_position(tauri::PhysicalPosition::new(x, y));
    } else {
        let _ = window.set_position(tauri::PhysicalPosition::new(x.max(0), y.max(0)));
    }
}
