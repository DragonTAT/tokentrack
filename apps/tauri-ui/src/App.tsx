import { useEffect, useState } from "react";
import { getCurrentWindow } from "@tauri-apps/api/window";
import TrayPopover from "./views/TrayPopover";
import Dashboard from "./views/Dashboard";

export default function App() {
  const [windowLabel, setWindowLabel] = useState<string | null>(null);

  useEffect(() => {
    const win = getCurrentWindow();
    setWindowLabel(win.label);
  }, []);

  if (windowLabel === null) return null;
  if (windowLabel === "tray-popover") return <TrayPopover />;
  return <Dashboard />;
}
