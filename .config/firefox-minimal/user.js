// ===========================================================================
// minimal firefox — prefs the CSS depends on, plus the ones that remove
// chrome CSS cannot reach.
//
// user.js is re-applied to prefs.js on every startup, so anything here is
// pinned. To stop pinning a value, delete the line (and reset it once in
// about:config).
// ===========================================================================

// --- required ------------------------------------------------------------
// Without this Firefox never loads userChrome.css / userContent.css.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// macOS draws context menus natively, which CSS cannot touch at all. Turning
// this off hands the menus back to the XUL renderer so userChrome.css styles
// them. This is the single most visible pref here.
user_pref("widget.macos.native-context-menus", false);

// --- chrome removal that CSS cannot do ----------------------------------
// Tabs drawn inside the titlebar: no native title bar above the strip.
user_pref("browser.tabs.inTitlebar", 1);

// Compact density — smaller intrinsic metrics for everything we did not pin.
user_pref("browser.uidensity", 1);
user_pref("browser.compactmode.show", true);

// Dark chrome and dark content by default, so there is no white flash before
// userContent.css applies.
user_pref("browser.theme.toolbar-theme", 0);
user_pref("browser.theme.content-theme", 0);
user_pref("ui.systemUsesDarkTheme", 1);
user_pref("layout.css.prefers-color-scheme.content-override", 0);

// Blank new tab. Nothing to read, nothing to load.
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.startup.homepage", "about:blank");
user_pref("browser.startup.page", 0);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);

// --- the address bar behaves like dmenu ---------------------------------
// No hover preview cards, no quick actions, no search-mode chiclets, no
// trending junk: the popup is a list of matches and nothing else.
user_pref("browser.urlbar.quickactions.enabled", false);
user_pref("browser.urlbar.quickactions.showPrefs", false);
user_pref("browser.urlbar.suggest.quickactions", false);
user_pref("browser.urlbar.suggest.trending", false);
user_pref("browser.urlbar.trending.featureGate", false);
user_pref("browser.urlbar.weather.featureGate", false);
user_pref("browser.urlbar.suggest.weather", false);
user_pref("browser.urlbar.suggest.topsites", false);
user_pref("browser.urlbar.suggest.calculator", true); // genuinely useful
user_pref("browser.urlbar.unitConversion.enabled", true);
user_pref("browser.urlbar.maxRichResults", 8);
user_pref("browser.urlbar.resultMenu", false);
user_pref("browser.urlbar.showSearchTerms.featureGate", false);

// Show the real URL, unabridged, when focused; trimmed when not.
user_pref("browser.urlbar.trimURLs", true);
user_pref("browser.urlbar.trimHttps", true);
user_pref("browser.urlbar.clickSelectsAll", true);

// --- no motion -----------------------------------------------------------
user_pref("browser.tabs.cardPreview.enabled", false);
user_pref("browser.tabs.hoverPreview.enabled", false);
user_pref("browser.tabs.tabmanager.enabled", false);
user_pref("full-screen-api.transition-duration.enter", "0 0");
user_pref("full-screen-api.transition-duration.leave", "0 0");
user_pref("full-screen-api.warning.timeout", 0);
user_pref("browser.fullscreen.autohide", true);
user_pref("ui.prefersReducedMotion", 1);

// --- no nagging ----------------------------------------------------------
user_pref("browser.aboutConfig.showWarning", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.tabs.warnOnCloseOtherTabs", false);
user_pref("browser.warnOnQuit", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.download.autohideButton", true);
user_pref("extensions.pocket.enabled", false);
user_pref("identity.fxaccounts.toolbar.enabled", false);
user_pref("browser.privatebrowsing.vpnpromourl", "");
user_pref("browser.preferences.moreFromMozilla", false);

// --- bookmarks ------------------------------------------------------------
// Firefox has native urlbar "restriction tokens" that scope a query to one
// source. `*` restricts to bookmarks, so typing `* rust` in the prompt
// searches only bookmarks. These prefs keep that behaviour switched on and
// make the bookmark results worth reading.
//
// Cmd+Shift+O opens the full Bookmarks Library (keyboard-navigable: type to
// filter, arrows to move, Enter to open). Cmd+B toggles the sidebar.
user_pref("browser.urlbar.suggest.bookmark", true);
user_pref("browser.urlbar.suggest.openpage", true);
user_pref("browser.urlbar.suggest.history", true);

// Rank bookmarks above plain history in the prompt, so a thing you deliberately
// saved outranks a page you happened to visit.
user_pref("browser.urlbar.showSearchSuggestionsFirst", false);

// The sidebar is where the keyboard-navigable bookmark tree lives; keep it on
// the left and let it be summoned without the rest of the sidebar furniture.
user_pref("sidebar.position_start", true);
user_pref("sidebar.revamp", false);
