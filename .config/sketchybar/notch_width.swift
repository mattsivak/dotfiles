// Prints the width of the built-in display's notch, in points.
//
// AppKit gives the two lit regions either side of the notch; the notch is the
// gap between them. Printing nothing (rather than a guess) when there is no
// notch lets the caller fall back deliberately.
//
// Used by notch.sh at bar load. Run: swift notch_width.swift

import AppKit

for screen in NSScreen.screens {
    // auxiliaryTopLeftArea is nil on any screen without a notch.
    guard let left = screen.auxiliaryTopLeftArea,
          let right = screen.auxiliaryTopRightArea else { continue }

    let notch = screen.frame.width - left.width - right.width
    if notch > 0 {
        print(Int(notch.rounded()))
        exit(0)
    }
}

exit(1)
