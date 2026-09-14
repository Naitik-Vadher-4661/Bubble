import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Bubble
import Quill as Q

Q.Dialog {
    id: root
    anchors.fill: parent
    z: 1000
    dialogWidth: 440
    title: {
        if (mode === "lock") return targets.length > 1 ? "Lock " + targets.length + " Items" : (isDir ? "Lock Folder" : "Lock File")
        if (mode === "change") return "Change Lock Password"
        if (isPermanent) return isDir ? "Unlock Folder Permanently" : "Unlock File Permanently"
        if (sessionOnly) return isDir ? "Unlock Folder" : "Unlock File"
        return isDir ? "Unlock Folder" : "Open Locked File"
    }
    subtitle: targets.length === 1 ? fileName : (targets.length + " items selected")
    initialFocusItem: (mode === "change" ? currentPasswordField : passwordField)

    // "lock", "unlock", "change"
    property string mode: "unlock"
    property bool isPermanent: false
    property bool sessionOnly: false
    property var targets: []
    property string targetPath: targets.length > 0 ? targets[0] : ""
    property bool isDir: false
    property string fileName: {
        if (!targetPath) return ""
        var parts = String(targetPath).split("/")
        return parts[parts.length - 1] || targetPath
    }
    property string errorText: ""
    property bool checking: false
    property int lockoutSeconds: 0

    Timer {
        id: lockoutTimer
        interval: 1000
        repeat: true
        running: root.lockoutSeconds > 0
        onTriggered: {
            if (root.lockoutSeconds > 0) {
                root.lockoutSeconds--
                if (root.lockoutSeconds === 0) {
                    root.errorText = ""
                } else {
                    root.errorText = "Too many failed attempts. Try again in " + root.lockoutSeconds + "s."
                }
            }
        }
    }

    function checkLockout(path) {
        if (typeof vault !== "undefined" && vault && path) {
            var rem = vault.getRemainingLockoutSeconds(path)
            if (rem > 0) {
                root.lockoutSeconds = rem
                root.errorText = "Too many failed attempts. Try again in " + rem + "s."
                return true
            }
        }
        root.lockoutSeconds = 0
        return false
    }

    signal unlocked(string path)
    signal locked(string path)
    signal passwordChanged(string path)

    function openForLock(paths, isDirectory) {
        root.mode = "lock"
        root.targets = Array.isArray(paths) ? paths : [paths]
        root.isDir = !!isDirectory
        root.isPermanent = false
        root.sessionOnly = false
        root.lockoutSeconds = 0
        root.errorText = ""
        root.checking = false
        passwordField.text = ""
        confirmPasswordField.text = ""
        root.open()
    }

    function openForUnlock(path, isDirectory, sessionOnlyFlag) {
        root.mode = "unlock"
        root.targets = [path]
        root.isDir = !!isDirectory
        root.isPermanent = false
        root.sessionOnly = !!sessionOnlyFlag
        root.errorText = ""
        root.checking = false
        passwordField.text = ""
        checkLockout(path)
        root.open()
    }

    function openForPermanentUnlock(path, isDirectory) {
        root.mode = "unlock"
        root.targets = [path]
        root.isDir = !!isDirectory
        root.isPermanent = true
        root.sessionOnly = false
        root.errorText = ""
        root.checking = false
        passwordField.text = ""
        checkLockout(path)
        root.open()
    }

    function openForChange(path) {
        root.mode = "change"
        root.targets = [path]
        root.isDir = false
        root.sessionOnly = false
        root.lockoutSeconds = 0
        root.errorText = ""
        root.checking = false
        currentPasswordField.text = ""
        passwordField.text = ""
        confirmPasswordField.text = ""
        root.open()
    }

    function submit() {
        if (root.checking) return
        root.errorText = ""

        if (mode === "lock") {
            var pass = passwordField.text
            var confirm = confirmPasswordField.text
            if (!pass) {
                root.errorText = "Password cannot be empty."
                return
            }
            if (pass !== confirm) {
                root.errorText = "Passwords do not match."
                return
            }
            root.checking = true
            var ok = false
            if (targets.length > 1) {
                ok = vault.lockItems(targets, pass)
            } else {
                ok = vault.lockItem(targetPath, pass)
            }
            root.checking = false
            if (ok) {
                root.locked(targetPath)
                root.accept()
            } else {
                var err = vault.lastError()
                root.errorText = err ? err : "Failed to lock item(s). Check permissions."
            }
        } else if (mode === "unlock") {
            if (root.lockoutSeconds > 0) {
                root.errorText = "Too many failed attempts. Try again in " + root.lockoutSeconds + "s."
                return
            }
            var pass = passwordField.text
            if (!pass) {
                root.errorText = "Enter the password."
                return
            }
            root.checking = true
            var ok = false
            if (isDir) {
                if (root.isPermanent) {
                    ok = vault.unlockItem(targetPath, pass)
                } else {
                    ok = vault.sessionUnlockFolder(targetPath, pass)
                }
            } else {
                if (root.isPermanent) {
                    ok = vault.unlockItem(targetPath, pass)
                } else if (root.sessionOnly) {
                    ok = vault.sessionUnlockFile(targetPath, pass)
                } else {
                    ok = vault.sessionOpenFile(targetPath, pass)
                }
            }
            root.checking = false
            if (ok) {
                root.lockoutSeconds = 0
                root.unlocked(targetPath)
                root.accept()
            } else {
                var rem = (typeof vault !== "undefined" && vault) ? vault.getRemainingLockoutSeconds(targetPath) : 0
                if (rem > 0) {
                    root.lockoutSeconds = rem
                    root.errorText = "Too many failed attempts. Try again in " + rem + "s."
                } else if (typeof vault !== "undefined" && vault && vault.lastError()) {
                    root.errorText = vault.lastError()
                } else {
                    root.errorText = "Access Denied: Incorrect password."
                }
                passwordField.inputItem.forceActiveFocus()
                passwordField.inputItem.selectAll()
            }
        } else if (mode === "change") {
            var oldPass = currentPasswordField.text
            var newPass = passwordField.text
            var confirmPass = confirmPasswordField.text
            if (!oldPass) {
                root.errorText = "Enter current password."
                return
            }
            if (!newPass) {
                root.errorText = "New password cannot be empty."
                return
            }
            if (newPass !== confirmPass) {
                root.errorText = "New passwords do not match."
                return
            }
            root.checking = true
            var ok = vault.changePassword(targetPath, oldPass, newPass)
            root.checking = false
            if (ok) {
                root.passwordChanged(targetPath)
                root.accept()
            } else {
                root.errorText = "Access Denied: Incorrect current password."
                currentPasswordField.inputItem.forceActiveFocus()
                currentPasswordField.inputItem.selectAll()
            }
        }
    }

    onOpened: Qt.callLater(function() {
        if (mode === "change") {
            currentPasswordField.inputItem.forceActiveFocus()
        } else {
            passwordField.inputItem.forceActiveFocus()
        }
    })

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        Q.TextField {
            id: currentPasswordField
            Layout.fillWidth: true
            variant: "filled"
            placeholder: "Current password"
            echoMode: TextInput.Password
            visible: root.mode === "change"
            enabled: !root.checking
            inputItem.Keys.onReturnPressed: root.submit()
            onTextChanged: root.errorText = ""
        }

        Q.TextField {
            id: passwordField
            Layout.fillWidth: true
            variant: "filled"
            placeholder: root.mode === "change" ? "New password" : "Password"
            echoMode: TextInput.Password
            enabled: !root.checking && (root.mode !== "unlock" || root.lockoutSeconds === 0)
            inputItem.Keys.onReturnPressed: root.submit()
            onTextChanged: root.errorText = ""
        }

        Q.TextField {
            id: confirmPasswordField
            Layout.fillWidth: true
            variant: "filled"
            placeholder: "Confirm password"
            echoMode: TextInput.Password
            visible: root.mode === "lock" || root.mode === "change"
            enabled: !root.checking
            inputItem.Keys.onReturnPressed: root.submit()
            onTextChanged: root.errorText = ""
        }

        Text {
            Layout.fillWidth: true
            visible: root.errorText !== ""
            text: root.errorText
            color: Theme.error
            font.pointSize: Theme.fontSmall
            wrapMode: Text.WordWrap
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: 12

        Q.Button {
            text: "Cancel"
            variant: "ghost"
            size: "small"
            onClicked: root.reject()
        }

        Q.Button {
            text: {
                if (root.checking) return "Working\u2026"
                if (root.mode === "unlock" && root.lockoutSeconds > 0) return "Locked (" + root.lockoutSeconds + "s)"
                if (root.mode === "lock") return "Lock"
                if (root.mode === "change") return "Change Password"
                if (root.isPermanent) return "Unlock Permanently"
                return root.isDir ? "Unlock Folder" : "Open File"
            }
            variant: "primary"
            size: "small"
            enabled: !root.checking && (root.mode !== "unlock" || root.lockoutSeconds === 0)
            onClicked: root.submit()
        }
    }
}
