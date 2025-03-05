# Copyright (c) 2025 Kassandra Pucher
#
# This software is provided ‘as-is’, without any express or implied
# warranty. In no event will the authors be held liable for any damages
# arising from the use of this software.
#
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
#
# 1. The origin of this software must not be misrepresented; you must not
# claim that you wrote the original software. If you use this software
# in a product, an acknowledgment in the product documentation would be
# appreciated but is not required.
#
# 2. Altered source versions must be plainly marked as such, and must not be
# misrepresented as being the original software.
#
# 3. This notice may not be removed or altered from any source
# distribution.
#
let
    pkgs = import <nixpkgs> { config = {}; overlays = []; };
    coreutils = pkgs."coreutils-full";
in
rec {
    eruption = pkgs.callPackage ./eruption.nix {};
    system_services = {
        eruption = {
            description = "Realtime RGB LED Driver for Linux";
            documentation = [ "man:eruption(8)" "man:eruption.conf(5)" "man:eruptionctl(1)" "man:eruption-netfx(1)" ];
            wants = [ "basic.target" ];
            wantedBy = [ "basic.target" ];
            startLimitIntervalSec = 300;
            startLimitBurst = 3;
            environment = {
                "RUST_LOG" = "warn";
            };

            serviceConfig = {
                RuntimeDirectory = "eruption";
                PIDFile = /run/eruption/eruption.pid;
                ExecStart = "${eruption}/bin/eruption -c ${eruption}/etc/eruption/eruption.conf";
                TimeoutStopSec = 10;
                Type = "exec";
                Restart = "always";
                WatchdogSec = 8;
                WatchdogSignal = "SIGKILL";
                CPUSchedulingPolicy = "rr";
                CPUSchedulingPriority = 20;
            };
        };
        "eruption-install-files" = {
            description = "Install all files for Eruption";
            after = [ "network.target" ];
            before = [ "eruption.service" ];
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStop = "${coreutils}/bin/rm -r /usr/share/eruption /usr/share/eruption-gui-gtk3 /var/lib/eruption/profiles /usr/share/man/man8/eruption.8 /usr/share/man/man8/eruption-cmd.8 /usr/share/man/man5/eruption.conf.5 /usr/share/man/man5/process-monitor.conf.5 /usr/share/man/man1/eruptionctl.1 /usr/share/man/man8/eruption-hwutil.8 /usr/share/man/man1/eruption-macro.1 /usr/share/man/man1/eruption-keymap.1 /usr/share/man/man1/eruption-netfx.1 /usr/share/man/man1/eruption-fx-proxy.1 /usr/share/man/man1/eruption-audio-proxy.1 /usr/share/man/man1/eruption-process-monitor.1";
                TimoutStopSec = 10;
            };
            script = ''
                for abs_path in $(find "${eruption}/usr/share" -type f) $(find "${eruption}/var/lib" -type f); do
                    rel_path=$(realpath --relative-to="${eruption}" "$abs_path")
                    mkdir -p $(dirname "/$rel_path")
                    ln -sf "$abs_path" "/$rel_path"
                done
            '';
            enable = true;
        };
    };
    user_services = {
        "eruption-audio-proxy" = {
            description = "Audio proxy daemon for Eruption";
            documentation = [ "man:eruption-audio-proxy(1)" "man:audio-proxy.conf(5)" "man:eruptionctl(1)" ];
            requires = [ "sound.target" ];
            partOf = [ "graphical-session.target" ];
            bindsTo = [ "graphical-session.target" ];
            wantedBy = [ "graphical-session.target" ];
            startLimitIntervalSec = 60;
            startLimitBurst = 3;
            environment = {
                "RUST_LOG" = "warn";
                "PULSE_LATENCY_MSEC" = "30";
            };

            serviceConfig = {
                ExecStart = "${eruption}/bin/eruption-audio-proxy -c /etc/eruption/audio-proxy.conf daemon";
                PIDFile = /run/eruption-audio-proxy.pid;
                Type = "exec";
                Restart = "always";
                RestartSec = 1;
            };
        };

        "eruption-fx-proxy" = {
            description = "Effects proxy daemon for Eruption";
            documentation = [ "man:eruption-fx-proxy(1)" "man:fx-proxy.conf(5)" "man:eruptionctl(1)" ];
            wants = [ "graphical-session.target" ];
            bindsTo = [ "graphical-session.target" ];
            wantedBy = [ "graphical-session.target" ];
            after = [ "graphical-session.target" ];
            startLimitIntervalSec = 60;
            startLimitBurst = 3;
            environment = {
                "RUST_LOG" = "warn";
            };

            serviceConfig = {
                ExecStart = "${eruption}/bin/eruption-fx-proxy -c /etc/eruption/fx-proxy.conf daemon";
                PIDFile = /run/eruption-audio-proxy.pid;
                Type = "exec";
                Restart = "always";
                RestartSec = 1;
            };
        };

        "eruption-process-monitor" = {
            description = "Process Monitoring and Introspection for Eruption";
            documentation = [ "man:eruption-process-monitor(1)" "man:process-monitor.conf(5)" "man:eruptionctl(1)" ];
            partOf = [ "graphical-session.target" ];
            bindsTo = [ "graphical-session.target" ];
            wantedBy = [ "graphical-session.target" ];
            startLimitIntervalSec = 60;
            startLimitBurst = 3;
            environment = {
                "RUST_LOG" = "warn";
            };

            serviceConfig = {
                PassEnvironment = "WAYLAND_DISPLAY XDG_SESSION_TYPE XDG_CURRENT_DESKTOP DISPLAY XAUTHORITY";
                ExecStart = "${eruption}/bin/eruption-process-monitor -c /etc/eruption/process-monitor.conf daemon";
                PIDFile = /run/eruption-process-monitor.pid;
                Type = "exec";
                Restart = "always";
                RestartSec = 1;
            };
        };
    };
    etc = {
        "eruption/eruption.conf".source = "${eruption}/etc/eruption/eruption.conf";
        "eruption/fx-proxy.conf".source = "${eruption}/etc/eruption/fx-proxy.conf";
        "eruption/audio-proxy.conf".source = "${eruption}/etc/eruption/audio-proxy.conf";
        "eruption/process-monitor.conf".source = "${eruption}/etc/eruption/process-monitor.conf";
        "eruption/profile.d/eruption.sh".source = "${eruption}/etc/eruption/profile.d/eruption.sh";
    };
}
