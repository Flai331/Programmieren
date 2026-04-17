/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#fef8e7',
          100: '#fde8b3',
          200: '#fcd879',
          300: '#fbc740',
          400: '#fab719',
          500: '#f9a825',
          600: '#f57f17',
          700: '#f57f17',
          800: '#e65100',
          900: '#d84315',
        },
      },
    },
  },
  plugins: [],
}
