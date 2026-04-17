import { useState, useEffect } from 'react';

/**
 * Custom Hook zur Erkennung von Mobilgeräten
 * Erkennt automatisch ob es sich um ein Mobilgerät handelt und
 * reagiert auf Änderungen der Bildschirmgröße
 */
export function useDeviceDetect() {
  const [deviceType, setDeviceType] = useState({
    isMobile: false,
    isTablet: false,
    isDesktop: true,
    screenWidth: typeof window !== 'undefined' ? window.innerWidth : 1024,
    screenHeight: typeof window !== 'undefined' ? window.innerHeight : 768,
    orientation: 'landscape',
    isTouchDevice: false,
  });

  useEffect(() => {
    // Prüft ob es ein Touch-Gerät ist
    const checkTouchDevice = () => {
      return (
        'ontouchstart' in window ||
        navigator.maxTouchPoints > 0 ||
        navigator.msMaxTouchPoints > 0
      );
    };

    // Ermittelt den Gerätetyp basierend auf Bildschirmbreite
    const getDeviceType = (width) => {
      // Breakpoints angelehnt an Tailwind CSS
      const MOBILE_BREAKPOINT = 640;  // sm
      const TABLET_BREAKPOINT = 1024; // lg

      return {
        isMobile: width < MOBILE_BREAKPOINT,
        isTablet: width >= MOBILE_BREAKPOINT && width < TABLET_BREAKPOINT,
        isDesktop: width >= TABLET_BREAKPOINT,
      };
    };

    // Ermittelt die Bildschirmausrichtung
    const getOrientation = () => {
      if (typeof window !== 'undefined') {
        return window.innerWidth > window.innerHeight ? 'landscape' : 'portrait';
      }
      return 'landscape';
    };

    // Handler für Größenänderungen
    const handleResize = () => {
      const width = window.innerWidth;
      const height = window.innerHeight;
      const device = getDeviceType(width);

      setDeviceType({
        ...device,
        screenWidth: width,
        screenHeight: height,
        orientation: getOrientation(),
        isTouchDevice: checkTouchDevice(),
      });
    };

    // Initial ausführen
    handleResize();

    // Event Listener hinzufügen
    window.addEventListener('resize', handleResize);
    window.addEventListener('orientationchange', handleResize);

    // Cleanup
    return () => {
      window.removeEventListener('resize', handleResize);
      window.removeEventListener('orientationchange', handleResize);
    };
  }, []);

  return deviceType;
}

/**
 * Breakpoint-Konstanten (angelehnt an Tailwind CSS)
 */
export const BREAKPOINTS = {
  sm: 640,
  md: 768,
  lg: 1024,
  xl: 1280,
  '2xl': 1536,
};

/**
 * Hilfsfunktion: Prüft ob Bildschirmbreite unter einem Breakpoint liegt
 */
export function useBreakpoint(breakpoint) {
  const { screenWidth } = useDeviceDetect();
  const breakpointValue = typeof breakpoint === 'number'
    ? breakpoint
    : BREAKPOINTS[breakpoint] || 640;

  return screenWidth < breakpointValue;
}

/**
 * Hilfsfunktion: Gibt den aktuellen Breakpoint-Namen zurück
 */
export function useCurrentBreakpoint() {
  const { screenWidth } = useDeviceDetect();

  if (screenWidth < BREAKPOINTS.sm) return 'xs';
  if (screenWidth < BREAKPOINTS.md) return 'sm';
  if (screenWidth < BREAKPOINTS.lg) return 'md';
  if (screenWidth < BREAKPOINTS.xl) return 'lg';
  if (screenWidth < BREAKPOINTS['2xl']) return 'xl';
  return '2xl';
}

export default useDeviceDetect;
