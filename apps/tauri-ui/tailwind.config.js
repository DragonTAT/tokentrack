/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          50: "#f0f4ff",
          100: "#dde6ff",
          500: "#6c8ef0",
          600: "#4f70e8",
          700: "#3a58d6",
          900: "#1a2d6e",
        },
      },
    },
  },
  plugins: [],
};
