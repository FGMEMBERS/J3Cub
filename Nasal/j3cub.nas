##########################################
# Autostart
##########################################

var autostart = func (msg=1) {
    if (getprop("/engines/active-engine/running")) {
        if (msg)
            gui.popupTip("Engine already running", 5);
        return;
    }

    setprop("/controls/switches/magnetos", 3);
    setprop("/controls/engines/current-engine/throttle", 0.2);
    setprop("/controls/engines/current-engine/mixture", 1.0);
    setprop("/controls/flight/elevator-trim", 0.0);
    setprop("/controls/switches/master-bat", 1);
    setprop("/controls/switches/master-alt", 1);
    setprop("/controls/switches/master-avionics", 1);

    # if empty get fuel or warn
    # setprop("/consumables/fuel/tank[0]/empty", 1);
   

    # Set the altimeter
    var pressure_sea_level = getprop("/environment/pressure-sea-level-inhg");
    setprop("/instrumentation/altimeter/setting-inhg", pressure_sea_level);

    # Pre-flight inspection
    setprop("/sim/model/j3cub/brake-parking", 0);
    setprop("/sim/model/j3cub/securing/chock", 0);
    setprop("/sim/model/j3cub/securing/pitot-cover-visible", 0);
    setprop("/sim/model/j3cub/securing/tiedownL-visible", 0);
    setprop("/sim/model/j3cub/securing/tiedownR-visible", 0);
    setprop("/sim/model/j3cub/securing/tiedownT-visible", 0);
    #setprop("/engines/active-engine/oil-level", 7.0);
    #setprop("/consumables/fuel/tank[0]/water-contamination", 0.0);
    
        ############################
    # All set, starting engine
    setprop("/controls/engines/current-engine/starter", 1);
    setprop("/engines/active-engine/auto-start", 1);
    
    #if (msg)
    #    gui.popupTip("Hold down \"s\" to start the engine", 5);
};

##########################################
# Brakes
##########################################

controls.applyBrakes = func (v, which = 0) {
    if (which <= 0 and !getprop("/fdm/jsbsim/gear/unit[1]/broken")) {
        interpolate("/controls/gear/brake-left", v, controls.fullBrakeTime);
    }
    if (which >= 0 and !getprop("/fdm/jsbsim/gear/unit[2]/broken")) {
        interpolate("/controls/gear/brake-right", v, controls.fullBrakeTime);
    }
};

controls.applyParkingBrake = func (v) {
    if (!v) {
        return;
    }

    var p = "/sim/model/j3cub/brake-parking";
    setprop(p, var i = !getprop(p));
    return i;
};

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
    if (getprop("/fdm/jsbsim/running")) {
        j3cub.autostart(0);
    }

    # These properties are aliased to MP properties in /sim/multiplay/generic/.
    # This aliasing seems to work in both ways, because the two properties below
    # appear to receive the random values from the MP properties during initialization.
    # Therefore, override these random values with the proper values we want.
    props.globals.getNode("/fdm/jsbsim/crash", 0).setBoolValue(0);
    props.globals.getNode("/fdm/jsbsim/gear/unit[0]/broken", 0).setBoolValue(0);
    props.globals.getNode("/fdm/jsbsim/gear/unit[1]/broken", 0).setBoolValue(0);
    props.globals.getNode("/fdm/jsbsim/gear/unit[2]/broken", 0).setBoolValue(0);
    props.globals.getNode("/fdm/jsbsim/pontoon-damage/left-pontoon", 0).setIntValue(0);
    props.globals.getNode("/fdm/jsbsim/pontoon-damage/right-pontoon", 0).setIntValue(0);
    props.globals.getNode("/fdm/jsbsim/ski-damage/left-ski", 0).setIntValue(0);
    props.globals.getNode("/fdm/jsbsim/ski-damage/right-ski", 0).setIntValue(0);
    setprop("/engines/active-engine/crash-engine", 0);
}

var update_pax = func {
    var state = 0;
    state = bits.switch(state, 0, getprop("pax/pilot/present"));
    state = bits.switch(state, 1, getprop("pax/passenger/present"));
    setprop("/payload/pax-state", state);
};

var update_securing = func {
    var state = 0;
    state = bits.switch(state, 0, getprop("/sim/model/j3cub/securing/pitot-cover-visible"));
    state = bits.switch(state, 1, getprop("/sim/model/j3cub/securing/chock-visible"));
    state = bits.switch(state, 2, getprop("/sim/model/j3cub/securing/tiedownL-visible"));
    state = bits.switch(state, 3, getprop("/sim/model/j3cub/securing/tiedownR-visible"));
    state = bits.switch(state, 4, getprop("/sim/model/j3cub/securing/tiedownT-visible"));
    setprop("/payload/securing-state", state);
};

##############
# Payload
##############
var capacity = 0.0;
var weight = 0.0;
var velocity = 0; 
var prior_view = "";
var payload_release = func {
    if (!getprop("/sim/model/payload")) {
        setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[15]", 0.0);  
        return;
    }
    if (getprop("/controls/armament/trigger") and
            getprop("/sim/model/payload") and 
            (!getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[15]") or
                getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[15]") < .01)) {
        logger.screen.white("Hopper is empty");
        setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[15]", 0);
        return;
    }
    if (getprop("/sim/current-view/view-number") == 0 and 
            (prior_view == 0 or prior_view == 1) and
            getprop("/sim/model/payload") == 1 and
            getprop("/sim/model/payload-package") < 2) {           
        setprop("/sim/current-view/view-number", 8);
        } else {
            if (getprop("/sim/current-view/view-number") == 0 and
            prior_view == 8)
                setprop("/sim/current-view/view-number", 1);

            if (!getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[1]"))
                setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[1]", getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[0]"));
            setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[0]", 0);
    }
    if (getprop("/sim/current-view/view-number") == 8 and
            getprop("/sim/model/payload") == 1 and
            getprop("/sim/model/payload-package") < 2 and
            getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[0]")) {
        logger.screen.white("Your not allowed to sit on hopper");
        if (!getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[1]"))
            setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[1]", getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[0]"));
        setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[0]", 0);
    }
    if (getprop("/sim/current-view/view-number") != 0 and
            getprop("/sim/current-view/view-number") != 8 and
            getprop("/sim/model/payload") == 1 and
            getprop("/sim/model/payload-package") < 2 and
            getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[0]")) {
        if (!getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[1]"))
            setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[1]", getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[0]"));
        setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[0]", 0);
    }   
    if (getprop("/controls/armament/trigger") and
            getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[15]") and
            getprop("/sim/model/payload-package") == 0 and
            getprop("/sim/model/payload")) {
        capacity = 0.01;    
        weight = getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[15]");
        velocity = getprop("/velocities/airspeed-kt");
        weight = weight - capacity * velocity;
        setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[15]", weight);
    } else if (getprop("/controls/armament/trigger") and
            getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[15]") and
            getprop("/sim/model/payload-package") == 1 and
            getprop("/sim/model/payload")) {
        capacity = .75;
        weight = getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[15]");
        velocity = 9.8;
        weight = weight - capacity * velocity;
        setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[15]", weight);
    } else if (getprop("/controls/armament/trigger") and
            getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[15]") and
            getprop("/sim/model/payload-package") == 2 and
            getprop("/sim/model/payload") and
            getprop("/sim/model/drums/rotate/position-norm") > .633) {
        capacity = 5;
        weight = getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[15]");
        velocity = 9.8;
        weight = weight - capacity * velocity;
        setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[15]", weight);
    }
    prior_view = getprop("/sim/current-view/view-number");
}

var drum_release = func {
    j3cub.drums.toggle();
}

var resolve_impact = func (n) {
    #print("Retardant impact!");
    var node = props.globals.getNode(n.getValue());
    var pos  = geo.Coord.new().set_latlon
                   (node.getNode("impact/latitude-deg").getValue(),
                    node.getNode("impact/longitude-deg").getValue(),
                    node.getNode("impact/elevation-m").getValue());
    # The arguments are: position, radius and volume (currently unused).
    wildfire.resolve_foam_drop(pos, 10, 0);
    #wildfire.resolve_retardant_drop(pos, 10, 0);
}

#var log_cabin_temp = func {
#    if (getprop("/sim/model/j3cub/enable-fog-frost")) {
#        var temp_degc = getprop("/fdm/jsbsim/heat/cabin-air-temp-degc");
#        if (temp_degc >= 32)
#            logger.screen.red("Cabin temperature exceeding 90F/32C!");
#        elsif (temp_degc <= 0)
#            logger.screen.red("Cabin temperature falling below 32F/0C!");
#    }
#};
#var cabin_temp_timer = maketimer(30.0, log_cabin_temp);
#var log_fog_frost = func {
#    if (getprop("/sim/model/j3cub/enable-fog-frost")) {
#        logger.screen.white("Wait until fog/frost clears up or decrease cabin air temperature");
#    }
#};
#var fog_frost_timer = maketimer(30.0, log_fog_frost);

#var set_limits = func () {
   
#    var limits = props.globals.getNode("/limits/mass-and-balance");
#    var ac_limits = props.globals.getNode("/limits/mass-and-balance");

    # Get the mass limits of the current engine
#    var ramp_mass = limits.getNode("maximum-ramp-mass-lbs");
#    var takeoff_mass = limits.getNode("maximum-takeoff-mass-lbs");
#    var landing_mass = limits.getNode("maximum-landing-mass-lbs");

    # Get the actual mass limit nodes of the aircraft
#    var ac_ramp_mass = ac_limits.getNode("maximum-ramp-mass-lbs");
#    var ac_takeoff_mass = ac_limits.getNode("maximum-takeoff-mass-lbs");
#    var ac_landing_mass = ac_limits.getNode("maximum-landing-mass-lbs");

    # Set the mass limits of the aircraft
#    ac_ramp_mass.unalias();
#    ac_takeoff_mass.unalias();
#    ac_landing_mass.unalias();

#    ac_ramp_mass.alias(ramp_mass);
#    ac_takeoff_mass.alias(takeoff_mass);
#    ac_landing_mass.alias(landing_mass);
#};

setlistener("/controls/engines/active-engine", func (node) {
    # Set new mass limits for Fuel and Payload Settings dialog
    #set_limits(node);

    # Emit a sound because the engine has been replaced
    click("engine-repair", 6.0);
}, 0, 0);

############################################
# Global loop function
# If you need to run nasal as loop, add it in this function
############################################
var global_system_loop = func {
    j3cub.physics_loop();

    if (getprop("/instrumentation/garmin196/antenne-deg") < 180) 
        setprop("/instrumentation/garmin196/antenne-deg", 180);
    payload_release();
}

##########################################
# SetListerner must be at the end of this file
##########################################
setlistener("/sim/signals/fdm-initialized", func {

    prior_view = getprop("/sim/current-view/view-number");

    # Use Nasal to make some properties persistent. <aircraft-data> does
    # not work reliably.
    #aircraft.data.add("/sim/model/j3cub/immat-on-panel");
    aircraft.data.load();

    # Listening for lightning strikes
    setlistener("/environment/lightning/lightning-pos-y", thunder);
    
    # Listen for release of payload
    setlistener("controls/armament/trigger", drum_release);
    
    # Listen for view impact of released payload
    setlistener("/sim/ai/aircraft/impact/retardant", resolve_impact);

    setlistener("/pax/pilot/present", update_pax, 0, 0);
    setlistener("/pax/passenger/present", update_pax, 0, 0);
    update_pax();
    
    setlistener("/sim/model/j3cub/securing/pitot-cover-visible", update_securing, 0, 0);
    setlistener("/sim/model/j3cub/securing/chock-visible", update_securing, 0, 0);
    setlistener("/sim/model/j3cub/securing/tiedownL-visible", update_securing, 0, 0);
    setlistener("/sim/model/j3cub/securing/tiedownR-visible", update_securing, 0, 0);
    setlistener("/sim/model/j3cub/securing/tiedownT-visible", update_securing, 0, 0);
    update_securing();
    
    # Initialize mass limits
    #set_limits();

    setlistener("/engines/active-engine/running", func (node) {
        var autostart = getprop("/engines/active-engine/auto-start");
        var cranking  = getprop("/engines/active-engine/cranking");
        if (cranking and node.getBoolValue()) {
            setprop("/controls/engines/current-engine/starter", 0);
            setprop("/engines/active-engine/auto-start", 0);
        }
    }, 0, 0);
    
    setprop("/sim/rendering/als-secondary-lights/landing-light1-offset-deg", 1);
    setprop("/sim/rendering/als-secondary-lights/landing-light2-offset-deg", -4);
    setprop("/sim/rendering/als-secondary-lights/landing-light3-offset-deg", 3);

    reset_system();
    j3cub.rightWindow.toggle();
    j3cub.rightDoor.toggle();

    var j3cub_timer = maketimer(0.25, func{global_system_loop()});
    j3cub_timer.start();
});
