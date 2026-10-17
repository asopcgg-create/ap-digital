import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import { VitePWA } from 'vite-plugin-pwa';
export default defineConfig({ plugins: [react(), tailwindcss(), VitePWA({registerType:'autoUpdate', includeAssets:['icon.svg','icon-192.png','icon-512.png','apple-touch-icon.png'], manifest:{name:'APCGG Digital · AP Digital',short_name:'APCGG',description:'Comunitatea părinților, mai aproape.',lang:'ro',start_url:'/',scope:'/',display:'standalone',theme_color:'#153e35',background_color:'#f6f7f2',icons:[{src:'/icon-192.png',sizes:'192x192',type:'image/png'},{src:'/icon-512.png',sizes:'512x512',type:'image/png',purpose:'any maskable'}]},workbox:{globPatterns:['**/*.{js,css,html,svg,png,webmanifest}'],navigateFallback:'/index.html',cleanupOutdatedCaches:true}})] });
