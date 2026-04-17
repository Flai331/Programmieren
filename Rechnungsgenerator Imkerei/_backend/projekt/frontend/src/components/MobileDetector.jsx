import { createContext, useContext, useState, useEffect, useCallback } from 'react';

/**
 * MobileDetector - Automatische Mobilgeräteerkennung mit Umschaltung auf Mobilversion
 *
 * Diese Datei enthält:
 * 1. ViewModeContext - Context für den aktuellen Ansichtsmodus (mobile/desktop)
 * 2. ViewModeProvider - Provider mit automatischer Erkennung und manuellem Override
 * 3. Hilfskomponenten für bedingte Darstellung
 * 4. Hook für einfachen Zugriff auf den Ansichtsmodus
 */

// ============================================================================
// KONSTANTEN
// ============================================================================

const BREAKPOINTS = {
  mobile: 640,    // Unter 640px = Mobil
  tablet: 1024,   // 640-1024px = Tablet
  desktop: 1024,  // Über 1024px = Desktop
};

const VIEW_MODES = {
  MOBILE: 'mobile',
  DESKTOP: 'desktop',
  AUTO: 'auto', // Automatische Erkennung
};

const STORAGE_KEY = 'app_view_mode_preference';

// ============================================================================
// CONTEXT
// ============================================================================

const ViewModeContext = createContext({
  // Aktueller Ansichtsmodus
  viewMode: VIEW_MODES.DESKTOP,
  // Ob aktuell die mobile Ansicht aktiv ist
  isMobileView: false,
  // Ob aktuell die Desktop Ansicht aktiv ist
  isDesktopView: true,
  // Der automatisch erkannte Gerätetyp (unabhängig vom manuellen Override)
  detectedDevice: {
    isMobile: false,
    isTablet: false,
    isDesktop: true,
    isTouchDevice: false,
    screenWidth: 1024,
    screenHeight: 768,
    orientation: 'landscape',
  },
  // Ob die automatische Erkennung aktiv ist
  isAutoMode: true,
  // Manuell auf Mobile umschalten
  switchToMobile: () => {},
  // Manuell auf Desktop umschalten
  switchToDesktop: () => {},
  // Automatische Erkennung aktivieren
  switchToAuto: () => {},
  // Toggle zwischen Mobile und Desktop
  toggleViewMode: () => {},
});

// ============================================================================
// PROVIDER KOMPONENTE
// ============================================================================

export function ViewModeProvider({ children, defaultMode = VIEW_MODES.AUTO }) {
  // Gespeicherte Präferenz aus localStorage laden
  const getSavedPreference = () => {
    if (typeof window === 'undefined') return defaultMode;
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved && Object.values(VIEW_MODES).includes(saved)) {
      return saved;
    }
    return defaultMode;
  };

  // State für manuellen Override (auto = automatische Erkennung)
  const [manualMode, setManualMode] = useState(getSavedPreference);

  // State für erkanntes Gerät
  const [detectedDevice, setDetectedDevice] = useState({
    isMobile: false,
    isTablet: false,
    isDesktop: true,
    isTouchDevice: false,
    screenWidth: typeof window !== 'undefined' ? window.innerWidth : 1024,
    screenHeight: typeof window !== 'undefined' ? window.innerHeight : 768,
    orientation: 'landscape',
  });

  // Geräteerkennung
  useEffect(() => {
    const checkTouchDevice = () => {
      return (
        'ontouchstart' in window ||
        navigator.maxTouchPoints > 0 ||
        navigator.msMaxTouchPoints > 0
      );
    };

    const getDeviceType = (width) => ({
      isMobile: width < BREAKPOINTS.mobile,
      isTablet: width >= BREAKPOINTS.mobile && width < BREAKPOINTS.tablet,
      isDesktop: width >= BREAKPOINTS.desktop,
    });

    const getOrientation = () => {
      return window.innerWidth > window.innerHeight ? 'landscape' : 'portrait';
    };

    const handleResize = () => {
      const width = window.innerWidth;
      const height = window.innerHeight;
      const device = getDeviceType(width);

      setDetectedDevice({
        ...device,
        screenWidth: width,
        screenHeight: height,
        orientation: getOrientation(),
        isTouchDevice: checkTouchDevice(),
      });
    };

    // Initial ausführen
    handleResize();

    // Event Listener
    window.addEventListener('resize', handleResize);
    window.addEventListener('orientationchange', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
      window.removeEventListener('orientationchange', handleResize);
    };
  }, []);

  // Präferenz speichern
  useEffect(() => {
    if (typeof window !== 'undefined') {
      localStorage.setItem(STORAGE_KEY, manualMode);
    }
  }, [manualMode]);

  // Berechne den effektiven Ansichtsmodus
  const isAutoMode = manualMode === VIEW_MODES.AUTO;

  const isMobileView = isAutoMode
    ? detectedDevice.isMobile || detectedDevice.isTablet // Im Auto-Modus: Mobile wenn kleiner als Desktop
    : manualMode === VIEW_MODES.MOBILE;

  const isDesktopView = !isMobileView;

  const viewMode = isMobileView ? VIEW_MODES.MOBILE : VIEW_MODES.DESKTOP;

  // Umschaltfunktionen
  const switchToMobile = useCallback(() => {
    setManualMode(VIEW_MODES.MOBILE);
  }, []);

  const switchToDesktop = useCallback(() => {
    setManualMode(VIEW_MODES.DESKTOP);
  }, []);

  const switchToAuto = useCallback(() => {
    setManualMode(VIEW_MODES.AUTO);
  }, []);

  const toggleViewMode = useCallback(() => {
    if (isMobileView) {
      setManualMode(VIEW_MODES.DESKTOP);
    } else {
      setManualMode(VIEW_MODES.MOBILE);
    }
  }, [isMobileView]);

  const value = {
    viewMode,
    isMobileView,
    isDesktopView,
    detectedDevice,
    isAutoMode,
    switchToMobile,
    switchToDesktop,
    switchToAuto,
    toggleViewMode,
  };

  return (
    <ViewModeContext.Provider value={value}>
      {children}
    </ViewModeContext.Provider>
  );
}

// ============================================================================
// HOOKS
// ============================================================================

/**
 * Hook zum Abrufen des aktuellen Ansichtsmodus
 */
export function useViewMode() {
  const context = useContext(ViewModeContext);
  if (context === undefined) {
    throw new Error('useViewMode muss innerhalb eines ViewModeProvider verwendet werden');
  }
  return context;
}

/**
 * Einfacher Hook der nur zurückgibt ob mobile Ansicht aktiv ist
 */
export function useIsMobileView() {
  const { isMobileView } = useViewMode();
  return isMobileView;
}

// ============================================================================
// BEDINGTE RENDER-KOMPONENTEN
// ============================================================================

/**
 * Zeigt Inhalt nur in der mobilen Ansicht
 */
export function MobileView({ children }) {
  const { isMobileView } = useViewMode();
  return isMobileView ? children : null;
}

/**
 * Zeigt Inhalt nur in der Desktop Ansicht
 */
export function DesktopView({ children }) {
  const { isDesktopView } = useViewMode();
  return isDesktopView ? children : null;
}

/**
 * Rendert unterschiedliche Inhalte je nach Ansichtsmodus
 */
export function ViewSwitch({ mobile, desktop, fallback = null }) {
  const { isMobileView, isDesktopView } = useViewMode();

  if (isMobileView && mobile) return mobile;
  if (isDesktopView && desktop) return desktop;
  return fallback;
}

// ============================================================================
// UI-KOMPONENTE: Ansichtsmodus-Umschalter
// ============================================================================

/**
 * Toggle-Button zum Umschalten zwischen Mobile und Desktop Ansicht
 * Kann in der App platziert werden um manuelle Umschaltung zu ermöglichen
 */
export function ViewModeToggle({ className = '' }) {
  const { isMobileView, isAutoMode, toggleViewMode, switchToAuto, detectedDevice } = useViewMode();

  return (
    <div className={`flex items-center gap-2 ${className}`}>
      {/* Auto-Modus Button */}
      <button
        onClick={switchToAuto}
        className={`
          px-3 py-1.5 text-xs font-medium rounded-md transition-colors
          ${isAutoMode
            ? 'bg-primary-100 text-primary-700 border border-primary-300'
            : 'bg-gray-100 text-gray-600 hover:bg-gray-200 border border-gray-300'
          }
        `}
        title="Automatische Erkennung"
      >
        Auto
      </button>

      {/* View Mode Toggle */}
      <button
        onClick={toggleViewMode}
        className={`
          flex items-center gap-2 px-3 py-1.5 text-xs font-medium rounded-md
          border border-gray-300 bg-white hover:bg-gray-50 transition-colors
        `}
        title={isMobileView ? 'Zur Desktop-Ansicht wechseln' : 'Zur Mobil-Ansicht wechseln'}
      >
        {/* Mobile Icon */}
        <svg
          className={`w-4 h-4 ${isMobileView ? 'text-primary-600' : 'text-gray-400'}`}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z"
          />
        </svg>

        {/* Toggle Switch */}
        <div className="relative w-8 h-4 bg-gray-300 rounded-full">
          <div
            className={`
              absolute top-0.5 w-3 h-3 bg-white rounded-full shadow transition-transform
              ${isMobileView ? 'left-0.5' : 'left-4'}
            `}
          />
        </div>

        {/* Desktop Icon */}
        <svg
          className={`w-4 h-4 ${!isMobileView ? 'text-primary-600' : 'text-gray-400'}`}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
          />
        </svg>
      </button>

      {/* Aktueller Status Anzeige */}
      <span className="text-xs text-gray-500">
        {isAutoMode && (
          <span className="text-gray-400">
            (erkannt: {detectedDevice.isMobile ? 'Mobil' : detectedDevice.isTablet ? 'Tablet' : 'Desktop'})
          </span>
        )}
      </span>
    </div>
  );
}

/**
 * Kompakte Version des Toggle-Buttons (nur Icon)
 */
export function ViewModeToggleCompact({ className = '' }) {
  const { isMobileView, toggleViewMode } = useViewMode();

  return (
    <button
      onClick={toggleViewMode}
      className={`
        p-2 rounded-md border border-gray-300 bg-white hover:bg-gray-50
        transition-colors ${className}
      `}
      title={isMobileView ? 'Zur Desktop-Ansicht wechseln' : 'Zur Mobil-Ansicht wechseln'}
    >
      {isMobileView ? (
        // Desktop Icon (wenn aktuell mobile)
        <svg className="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
          />
        </svg>
      ) : (
        // Mobile Icon (wenn aktuell desktop)
        <svg className="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z"
          />
        </svg>
      )}
    </button>
  );
}

// ============================================================================
// EXPORTS
// ============================================================================

export { VIEW_MODES, BREAKPOINTS };
export default ViewModeProvider;
