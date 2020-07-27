// This function is used by lib/check_localstorage.dart

function checkLocalStorage() {
    try {
        let key = 'O09DGzSpoH';
        localStorage.setItem(key, 'test');
        localStorage.removeItem(key);
        return true;
    } catch(e) {
        return false;
    }
}