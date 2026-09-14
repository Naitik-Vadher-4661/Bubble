#include <iostream>
#include <string>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/fs.h>
#include <sys/stat.h>
#include <dirent.h>
#include <cstring>
#include <cerrno>
#include <cstdlib>

static bool setImmutableFlag(const char *path, bool immutable)
{
    struct stat st;
    if (lstat(path, &st) != 0) {
        return false;
    }
    if (S_ISLNK(st.st_mode)) {
        return false;
    }

    int openFlags = O_RDONLY | O_NONBLOCK;
    if (S_ISDIR(st.st_mode)) {
        openFlags |= O_DIRECTORY;
    }

    int fd = open(path, openFlags);
    if (fd < 0) {
        return false;
    }

    long flags = 0;
    if (ioctl(fd, FS_IOC_GETFLAGS, &flags) < 0) {
        close(fd);
        return false;
    }

    if (immutable) {
        flags |= FS_IMMUTABLE_FL;
    } else {
        flags &= ~FS_IMMUTABLE_FL;
    }

    int res = ioctl(fd, FS_IOC_SETFLAGS, &flags);
    close(fd);
    return res >= 0;
}

static void recursivePrepareWrite(const std::string &path, uid_t targetUid, gid_t targetGid)
{
    struct stat st;
    if (lstat(path.c_str(), &st) != 0) return;
    if (S_ISLNK(st.st_mode)) return;

    // Clear immutable flag first in case it was locked
    setImmutableFlag(path.c_str(), false);

    // Chown to the target user and make readable/writable
    if (targetUid > 0) {
        chown(path.c_str(), targetUid, targetGid);
    }

    if (S_ISDIR(st.st_mode)) {
        chmod(path.c_str(), 0755);
        DIR *dir = opendir(path.c_str());
        if (dir) {
            struct dirent *entry;
            while ((entry = readdir(dir)) != nullptr) {
                if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
                    continue;
                std::string childPath = path + "/" + entry->d_name;
                recursivePrepareWrite(childPath, targetUid, targetGid);
            }
            closedir(dir);
        }
    } else if (S_ISREG(st.st_mode)) {
        chmod(path.c_str(), 0644);
    }
}

static void recursiveProtect(const std::string &path)
{
    struct stat st;
    if (lstat(path.c_str(), &st) != 0) return;
    if (S_ISLNK(st.st_mode)) return;

    if (S_ISDIR(st.st_mode)) {
        DIR *dir = opendir(path.c_str());
        if (dir) {
            struct dirent *entry;
            while ((entry = readdir(dir)) != nullptr) {
                if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
                    continue;
                std::string childPath = path + "/" + entry->d_name;
                recursiveProtect(childPath);
            }
            closedir(dir);
        }
        chmod(path.c_str(), 0000);
        setImmutableFlag(path.c_str(), true);
    } else if (S_ISREG(st.st_mode)) {
        chmod(path.c_str(), 0000);
        setImmutableFlag(path.c_str(), true);
    }
}

static void recursiveUnprotect(const std::string &path, mode_t dirMode, mode_t fileMode)
{
    struct stat st;
    if (lstat(path.c_str(), &st) != 0) return;
    if (S_ISLNK(st.st_mode)) return;

    setImmutableFlag(path.c_str(), false);
    if (S_ISDIR(st.st_mode)) {
        chmod(path.c_str(), dirMode);
        DIR *dir = opendir(path.c_str());
        if (dir) {
            struct dirent *entry;
            while ((entry = readdir(dir)) != nullptr) {
                if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
                    continue;
                std::string childPath = path + "/" + entry->d_name;
                recursiveUnprotect(childPath, dirMode, fileMode);
            }
            closedir(dir);
        }
    } else if (S_ISREG(st.st_mode)) {
        chmod(path.c_str(), fileMode);
    }
}

int main(int argc, char *argv[])
{
    if (argc < 3) {
        std::cerr << "Usage: bubble-vault-helper <command> <path> [args...]\n";
        return 1;
    }

    // Elevate to root effective UID if running with setuid root
    if (seteuid(0) != 0) {
        // Non-fatal if running directly as root or through pkexec
    }

    std::string cmd = argv[1];
    std::string path = argv[2];

    if (cmd == "+i") {
        return setImmutableFlag(path.c_str(), true) ? 0 : 1;
    } else if (cmd == "-i") {
        return setImmutableFlag(path.c_str(), false) ? 0 : 1;
    } else if (cmd == "prepare-write") {
        uid_t targetUid = (argc >= 4) ? static_cast<uid_t>(std::strtoul(argv[3], nullptr, 10)) : getuid();
        gid_t targetGid = (argc >= 5) ? static_cast<gid_t>(std::strtoul(argv[4], nullptr, 10)) : getgid();
        recursivePrepareWrite(path, targetUid, targetGid);
        return 0;
    } else if (cmd == "protect") {
        recursiveProtect(path);
        return 0;
    } else if (cmd == "unprotect") {
        recursiveUnprotect(path, 0755, 0644);
        return 0;
    } else if (cmd == "chmod") {
        if (argc >= 4) {
            mode_t mode = static_cast<mode_t>(std::strtoul(argv[3], nullptr, 8));
            return chmod(path.c_str(), mode) == 0 ? 0 : 1;
        }
    }

    std::cerr << "Unknown command: " << cmd << "\n";
    return 1;
}
