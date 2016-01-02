##########################################
# Click Sounds
##########################################

var click = func (name, timeout=0.1, delay=0) {
    var sound_prop = "/sim/model/j3cub/sound/click-" ~ name;

    settimer(func {
        # Play the sound
        setprop(sound_prop, 1);

        # Reset the property after 0.2 seconds so that the sound can be
        # played again.
        settimer(func {
            setprop(sound_prop, 0);
        }, timeout);
    }, delay);
};

##########################################
# Thunder Sound
##########################################

var speed_of_sound = func (t, re) {
    # Compute speed of sound in m/s
    #
    # t = temperature in Celsius
    # re = amount of water vapor in the air

    # Compute virtual temperature using mixing ratio (amount of water vapor)
    # Ratio of gas constants of dry air and water vapor: 287.058 / 461.5 = 0.622
    var T = 273.15 + t;
    var v_T = T * (1 + re/0.622)/(1 + re);

    # Compute speed of sound using adiabatic index, gas constant of air,
    # and virtual temperature in Kelvin.
    return math.sqrt(1.4 * 287.058 * v_T);
};

var thunder = func (name) {
    var thunderCalls = 0;

    var lightning_pos_x = getprop("/environment/lightning/lightning-pos-x");
    var lightning_pos_y = getprop("/environment/lightning/lightning-pos-y");
    var lightning_distance = math.sqrt(math.pow(lightning_pos_x, 2) + math.pow(lightning_pos_y, 2));

    # On the ground, thunder can be heard up to 16 km. Increase this value
    # a bit because the aircraft is usually in the air.
    if (lightning_distance > 20000)
        return;

    var t = getprop("/environment/temperature-degc");
    var re = getprop("/environment/relative-humidity") / 100;
    var delay_seconds = lightning_distance / speed_of_sound(t, re);

    # Maximum volume at 5000 meter
    var lightning_distance_norm = std.min(1.0, 1 / math.pow(lightning_distance / 5000.0, 2));

    settimer(func {
        var thunder1 = getprop("/sim/model/j3cub/sound/click-thunder1");
        var thunder2 = getprop("/sim/model/j3cub/sound/click-thunder2");
        var thunder3 = getprop("/sim/model/j3cub/sound/click-thunder3");

        if (!thunder1) {
            thunderCalls = 1;
            setprop("/sim/model/j3cub/sound/lightning/dist1", lightning_distance_norm);
        }
        else if (!thunder2) {
            thunderCalls = 2;
            setprop("/sim/model/j3cub/sound/lightning/dist2", lightning_distance_norm);
        }
        else if (!thunder3) {
            thunderCalls = 3;
            setprop("/sim/model/j3cub/sound/lightning/dist3", lightning_distance_norm);
        }
        else
            return;

        # Play the sound (sound files are about 9 seconds)
        click("thunder" ~ thunderCalls, 9.0, 0);
    }, delay_seconds);
};

var reset_system = func {
    # Note: these separate flags exist because PUI's <radio> element
    #       only accepts booleans.
    var p = getprop("fdm/jsbsim/bushkit");
    setprop("/sim/model/j3cub/bushkit_flag_0",0);
    setprop("/sim/model/j3cub/bushkit_flag_1",0);
    setprop("/sim/model/j3cub/bushkit_flag_2",0);
    setprop("/sim/model/j3cub/bushkit_flag_3",0);
    setprop("/sim/model/j3cub/bushkit_flag_4",0);
    if (p == 0) { setprop("/sim/model/j3cub/bushkit_flag_0",1); }
    if (p == 1) { setprop("/sim/model/j3cub/bushkit_flag_1",1); }
    if (p == 2) { setprop("/sim/model/j3cub/bushkit_flag_2",1); }
    if (p == 3) { setprop("/sim/model/j3cub/bushkit_flag_3",1); }
    if (p == 4) { setprop("/sim/model/j3cub/bushkit_flag_4",1); }
}

############################################
# Global loop function
# If you need to run nasal as loop, add it in this function
############################################
var global_system_loop = func {
    Cub.physics_loop();
}

##########################################
# SetListerner must be at the end of this file
##########################################
setlistener("/sim/signals/fdm-initialized", func {
    # Use Nasal to make some properties persistent. <aircraft-data> does
    # not work reliably.
    #aircraft.data.add("/sim/model/j3cub/immat-on-panel");
    aircraft.data.load();

    # Listening for lightning strikes
    setlistener("/environment/lightning/lightning-pos-y", thunder);

    reset_system();
    var j3cub_timer = maketimer(0.25, func{global_system_loop()});
    j3cub_timer.start();
});
