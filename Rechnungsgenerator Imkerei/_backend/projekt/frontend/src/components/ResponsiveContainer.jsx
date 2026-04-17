import { createContext, useContext } from 'react';
import { useDeviceDetect } from '../hooks/useDeviceDetect';

/**
 * Context für Geräteinformationen
 * Ermöglicht einfachen Zugriff auf Geräteinformationen in der gesamten App
 */
const DeviceContext = createContext({
  isMobile: false,
  isTablet: false,
  isDesktop: true,
  screenWidth: 1024,
  screenHeight: 768,
  orientation: 'landscape',
  isTouchDevice: false,
});

/**
 * Provider-Komponente für Geräteerkennung
 * Umschließt die App und stellt Geräteinformationen bereit
 */
export function DeviceProvider({ children }) {
  const deviceInfo = useDeviceDetect();

  return (
    <DeviceContext.Provider value={deviceInfo}>
      {children}
    </DeviceContext.Provider>
  );
}

/**
 * Hook zum Abrufen der Geräteinformationen aus dem Context
 */
export function useDevice() {
  const context = useContext(DeviceContext);
  if (context === undefined) {
    throw new Error('useDevice muss innerhalb eines DeviceProvider verwendet werden');
  }
  return context;
}

/**
 * Komponente die Inhalte nur auf Mobilgeräten anzeigt
 */
export function MobileOnly({ children }) {
  const { isMobile } = useDevice();
  return isMobile ? children : null;
}

/**
 * Komponente die Inhalte nur auf Tablets anzeigt
 */
export function TabletOnly({ children }) {
  const { isTablet } = useDevice();
  return isTablet ? children : null;
}

/**
 * Komponente die Inhalte nur auf Desktop-Geräten anzeigt
 */
export function DesktopOnly({ children }) {
  const { isDesktop } = useDevice();
  return isDesktop ? children : null;
}

/**
 * Komponente die Inhalte auf Mobilgeräten und Tablets anzeigt
 */
export function MobileAndTablet({ children }) {
  const { isMobile, isTablet } = useDevice();
  return isMobile || isTablet ? children : null;
}

/**
 * Komponente die Inhalte auf Tablets und Desktop-Geräten anzeigt
 */
export function TabletAndDesktop({ children }) {
  const { isTablet, isDesktop } = useDevice();
  return isTablet || isDesktop ? children : null;
}

/**
 * Responsive Container-Komponente
 * Rendert unterschiedliche Inhalte basierend auf dem Gerätetyp
 *
 * Beispiel:
 * <ResponsiveContainer
 *   mobile={<MobileNavigation />}
 *   tablet={<TabletNavigation />}
 *   desktop={<DesktopNavigation />}
 * />
 */
export function ResponsiveContainer({
  mobile,
  tablet,
  desktop,
  fallback = null
}) {
  const { isMobile, isTablet, isDesktop } = useDevice();

  if (isMobile && mobile) return mobile;
  if (isTablet && tablet) return tablet;
  if (isDesktop && desktop) return desktop;

  // Fallback-Logik: Wenn keine spezifische Version vorhanden ist
  if (isMobile) return tablet || desktop || fallback;
  if (isTablet) return desktop || mobile || fallback;
  if (isDesktop) return tablet || mobile || fallback;

  return fallback;
}

/**
 * Hilfsfunktion: Gibt responsive Klassen zurück basierend auf Gerätetyp
 */
export function useResponsiveClass(classes) {
  const { isMobile, isTablet, isDesktop } = useDevice();

  if (isMobile && classes.mobile) return classes.mobile;
  if (isTablet && classes.tablet) return classes.tablet;
  if (isDesktop && classes.desktop) return classes.desktop;
  return classes.default || '';
}

/**
 * Hilfsfunktion: Gibt responsive Werte zurück basierend auf Gerätetyp
 */
export function useResponsiveValue(values) {
  const { isMobile, isTablet, isDesktop } = useDevice();

  if (isMobile && values.mobile !== undefined) return values.mobile;
  if (isTablet && values.tablet !== undefined) return values.tablet;
  if (isDesktop && values.desktop !== undefined) return values.desktop;
  return values.default;
}

export default ResponsiveContainer;
