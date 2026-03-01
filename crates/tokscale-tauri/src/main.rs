// Prevents an additional console window on Windows in release mode
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;
mod state;
mod tray;

use tauri::Manager;

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(state::new_cache())
        .setup(|app| {
            tray::setup_tray(app)?;

            // Hide from dock on macOS — we're a menu bar app
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            // Pre-warm the cache on startup
            let cache = app.state::<state::SharedCache>().inner().clone();
            tauri::async_runtime::spawn(async move {
                let _ = state::refresh_cache(&cache).await;
            });

            // Auto-refresh cache every 5 minutes
            let cache = app.state::<state::SharedCache>().inner().clone();
            tauri::async_runtime::spawn(async move {
                let mut interval = tokio::time::interval(std::time::Duration::from_secs(300));
                interval.tick().await; // skip the first immediate tick
                loop {
                    interval.tick().await;
                    let _ = state::refresh_cache(&cache).await;
                }
            });

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::get_today_summary,
            commands::get_graph_data,
            commands::get_model_report,
            commands::get_monthly_report,
            commands::refresh_data,
            commands::get_supported_clients,
        ])
        .on_window_event(|window, event| {
            // Hide popover when it loses focus (click outside)
            if window.label() == "tray-popover" {
                if let tauri::WindowEvent::Focused(false) = event {
                    let _ = window.hide();
                }
            }
            // Prevent app exit when main window is closed — keep running in tray
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                if window.label() == "main" {
                    api.prevent_close();
                    let _ = window.hide();
                }
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running TokenTrack");
}
