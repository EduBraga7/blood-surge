import bpy
import math
import os

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_material(name, albedo_color, metallic=0.0, roughness=0.5, emission_color=(0,0,0,1), emission_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = albedo_color
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if emission_strength > 0:
            # Blender 4+ has Emission Color and Emission Strength
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = emission_color
                bsdf.inputs["Emission Strength"].default_value = emission_strength
            elif "Emission" in bsdf.inputs:
                bsdf.inputs["Emission"].default_value = emission_color
    return mat

def create_husk_model(export_path):
    clear_scene()
    
    # Materials
    mat_armor = create_material("HuskArmor", (0.10, 0.10, 0.13, 1.0), metallic=0.8, roughness=0.4)
    mat_flesh = create_material("HuskFlesh", (0.22, 0.16, 0.20, 1.0), metallic=0.2, roughness=0.7)
    mat_visor = create_material("HuskVisor", (1.0, 0.05, 0.05, 1.0), metallic=0.1, roughness=0.2,
                                emission_color=(1.0, 0.08, 0.08, 1.0), emission_strength=7.0)
    mat_teeth = create_material("HuskTeeth", (0.75, 0.70, 0.65, 1.0), metallic=0.1, roughness=0.5)

    root = bpy.data.objects.new("HuskRoot", None)
    bpy.context.scene.collection.objects.link(root)

    # 1. Torso / Ribcage (Aggressive hunched predator posture)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.95, 0.05))
    torso = bpy.context.active_object
    torso.name = "Torso"
    torso.scale = (0.32, 0.26, 0.42)
    torso.data.materials.append(mat_armor)
    torso.parent = root

    # Spine ridge
    for i in range(4):
        bpy.ops.mesh.primitive_cube_add(size=0.12, location=(0, 0.80 + i * 0.12, 0.22))
        spine = bpy.context.active_object
        spine.scale = (0.6, 0.8, 0.6)
        spine.rotation_euler = (math.radians(20), 0, 0)
        spine.data.materials.append(mat_flesh)
        spine.parent = root

    # 2. Head (Vicious triangular cyber-skull)
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.22, depth=0.35, location=(0, 1.45, -0.15))
    head = bpy.context.active_object
    head.name = "Head"
    head.rotation_euler = (math.radians(-75), 0, 0)
    head.scale = (0.9, 0.8, 1.0)
    head.data.materials.append(mat_armor)
    head.parent = root

    # Visor (Single menacing crimson slit across face)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 1.48, -0.32))
    visor = bpy.context.active_object
    visor.name = "Visor"
    visor.scale = (0.24, 0.05, 0.06)
    visor.data.materials.append(mat_visor)
    visor.parent = root

    # Lower Jaw / Mandibles
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 1.34, -0.28))
    jaw = bpy.context.active_object
    jaw.name = "Jaw"
    jaw.scale = (0.16, 0.18, 0.08)
    jaw.rotation_euler = (math.radians(15), 0, 0)
    jaw.data.materials.append(mat_flesh)
    jaw.parent = root

    # 3. Shoulders & Claw Arms
    for side, sign in [("L", -1), ("R", 1)]:
        # Shoulder pad
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.14, depth=0.22, location=(sign * 0.38, 1.25, 0.02))
        shoulder = bpy.context.active_object
        shoulder.rotation_euler = (0, math.radians(90 * sign), math.radians(20))
        shoulder.data.materials.append(mat_armor)
        shoulder.parent = root

        # Upper Arm
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * 0.42, 1.05, -0.06))
        arm_up = bpy.context.active_object
        arm_up.scale = (0.09, 0.10, 0.28)
        arm_up.rotation_euler = (math.radians(25), math.radians(-10 * sign), 0)
        arm_up.data.materials.append(mat_flesh)
        arm_up.parent = root

        # Forearm / Claw Base
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * 0.44, 0.78, -0.25))
        forearm = bpy.context.active_object
        forearm.scale = (0.08, 0.09, 0.32)
        forearm.rotation_euler = (math.radians(-40), math.radians(-15 * sign), 0)
        forearm.data.materials.append(mat_armor)
        forearm.parent = root

        # Serrated Claws (3 predatory blades per hand)
        for claw_idx in range(3):
            offset_x = (claw_idx - 1) * 0.05
            bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.035, depth=0.28,
                                            location=(sign * 0.44 + offset_x, 0.62, -0.42))
            claw = bpy.context.active_object
            claw.rotation_euler = (math.radians(-75), 0, math.radians(10 * offset_x * 50))
            claw.data.materials.append(mat_visor)
            claw.parent = root

    # 4. Legs (Digitigrade raptor legs)
    for side, sign in [("L", -1), ("R", 1)]:
        # Hip/Pelvis socket
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * 0.20, 0.70, 0.05))
        hip = bpy.context.active_object
        hip.scale = (0.12, 0.14, 0.14)
        hip.data.materials.append(mat_armor)
        hip.parent = root

        # Thigh
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * 0.22, 0.52, 0.12))
        thigh = bpy.context.active_object
        thigh.scale = (0.09, 0.11, 0.30)
        thigh.rotation_euler = (math.radians(-25), 0, 0)
        thigh.data.materials.append(mat_flesh)
        thigh.parent = root

        # Shin / Calf
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * 0.22, 0.25, -0.04))
        shin = bpy.context.active_object
        shin.scale = (0.08, 0.09, 0.32)
        shin.rotation_euler = (math.radians(35), 0, 0)
        shin.data.materials.append(mat_armor)
        shin.parent = root

        # Talon foot
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * 0.22, 0.05, -0.12))
        foot = bpy.context.active_object
        foot.scale = (0.12, 0.24, 0.08)
        foot.data.materials.append(mat_armor)
        foot.parent = root

    # Join or export with root
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=export_path, export_format='GLB', use_selection=True)
    print(f"HUSK MODEL EXPORTED: {export_path}")

def create_sentinel_model(export_path):
    clear_scene()

    # Materials
    mat_hull = create_material("SentinelHull", (0.12, 0.14, 0.18, 1.0), metallic=0.9, roughness=0.3)
    mat_gold = create_material("SentinelGold", (0.85, 0.55, 0.10, 1.0), metallic=0.8, roughness=0.35)
    mat_lens = create_material("SentinelLens", (1.0, 0.05, 0.05, 1.0), metallic=0.2, roughness=0.1,
                                emission_color=(1.0, 0.05, 0.05, 1.0), emission_strength=9.0)
    mat_thrust = create_material("SentinelThruster", (0.2, 0.8, 1.0, 1.0), metallic=0.1, roughness=0.2,
                                 emission_color=(0.1, 0.8, 1.0, 1.0), emission_strength=6.0)

    root = bpy.data.objects.new("SentinelRoot", None)
    bpy.context.scene.collection.objects.link(root)

    # 1. Central Core Sphere / Faceted Octahedron
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.48, location=(0, 0, 0))
    core = bpy.context.active_object
    core.name = "CoreBody"
    core.data.materials.append(mat_hull)
    core.parent = root

    # Front Mono-Eye Bezel
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.28, depth=0.16, location=(0, 0, -0.42))
    bezel = bpy.context.active_object
    bezel.rotation_euler = (math.radians(90), 0, 0)
    bezel.data.materials.append(mat_gold)
    bezel.parent = root

    # Glowing Red Mono-Eye (Central camera lens)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.20, depth=0.08, location=(0, 0, -0.48))
    lens = bpy.context.active_object
    lens.name = "EyeLens"
    lens.rotation_euler = (math.radians(90), 0, 0)
    lens.data.materials.append(mat_lens)
    lens.parent = root

    # 2. Outer Gyro Rings (Iconic floating drone look)
    # Ring 1: Pitch ring (Torus)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.72, minor_radius=0.045, major_segments=24, minor_segments=6, location=(0,0,0))
    ring1 = bpy.context.active_object
    ring1.name = "GyroRing_Pitch"
    ring1.rotation_euler = (math.radians(35), 0, 0)
    ring1.data.materials.append(mat_gold)
    ring1.parent = root

    # Ring 2: Yaw/Roll ring (Torus)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.86, minor_radius=0.04, major_segments=24, minor_segments=6, location=(0,0,0))
    ring2 = bpy.context.active_object
    ring2.name = "GyroRing_Yaw"
    ring2.rotation_euler = (0, math.radians(45), math.radians(65))
    ring2.data.materials.append(mat_hull)
    ring2.parent = root

    # 3. Plasma Projector Pylon (Underslung focus cannon)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.48, -0.18))
    pylon = bpy.context.active_object
    pylon.scale = (0.14, 0.12, 0.40)
    pylon.data.materials.append(mat_hull)
    pylon.parent = root

    # Emitter tip
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.09, depth=0.18, location=(0, -0.48, -0.42))
    tip = bpy.context.active_object
    tip.rotation_euler = (math.radians(-90), 0, 0)
    tip.data.materials.append(mat_lens)
    tip.parent = root

    # 4. Rear Ion Micro-Thrusters (3 stabilator jets)
    for angle_deg in [30, 150, 270]:
        rad = math.radians(angle_deg)
        tx = math.cos(rad) * 0.28
        ty = math.sin(rad) * 0.28
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.06, depth=0.14, location=(tx, ty, 0.42))
        thruster = bpy.context.active_object
        thruster.rotation_euler = (math.radians(90), 0, 0)
        thruster.data.materials.append(mat_hull)
        thruster.parent = root

        # Thruster exhaust flame/glow
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.045, depth=0.12, location=(tx, ty, 0.52))
        exhaust = bpy.context.active_object
        exhaust.rotation_euler = (math.radians(90), 0, 0)
        exhaust.data.materials.append(mat_thrust)
        exhaust.parent = root

    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=export_path, export_format='GLB', use_selection=True)
    print(f"SENTINEL MODEL EXPORTED: {export_path}")

if __name__ == "__main__":
    base_dir = r"C:\Users\du-xb\Documents\games\BLOODSURGE\assets\models"
    create_husk_model(os.path.join(base_dir, "husk.glb"))
    create_sentinel_model(os.path.join(base_dir, "sentinel.glb"))
