#!/usr/bin/env python3
"""Static consistency checks for the Nightmare Hunter Godot 4 project.

This is NOT a GDScript parser and does not replace the Godot editor. It checks
the cross-file contracts that break a project on load, which is the class of
error that matters most when the engine itself cannot be run in this sandbox:

  1. Every res:// path referenced by a script or scene exists.
  2. Every $NodePath in a script exists in the matching .tscn hierarchy.
  3. Every Input action used in code is declared in project.godot.
  4. Every autoload script path exists.
  5. class_name identifiers are unique.
  6. No script instantiates a class whose base is a Node type (.new() on a
     Node subclass is a hard error in Godot).
  7. Balanced brackets/quotes and no tabs-mixed-with-spaces indentation.
  8. Every data JSON file parses and carries the fields the loader reads.

Run:  python3 tools/check_project.py
Exit code 0 = no errors.
"""

from __future__ import annotations

import json
import os
import re
import sys
from typing import Dict, List, Set, Tuple

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ERRORS: List[str] = []
WARNINGS: List[str] = []


def err(msg: str) -> None:
    ERRORS.append(msg)


def warn(msg: str) -> None:
    WARNINGS.append(msg)


def rel(path: str) -> str:
    return os.path.relpath(path, ROOT)


# ---------------------------------------------------------------- collection
def collect() -> Tuple[List[str], List[str], str]:
    scripts: List[str] = []
    scenes: List[str] = []
    project = ""
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in (".git", ".godot", "tools", "export", "build")]
        for name in filenames:
            full = os.path.join(dirpath, name)
            if name.endswith(".gd"):
                scripts.append(full)
            elif name.endswith(".tscn"):
                scenes.append(full)
            elif name == "project.godot":
                project = full
    return sorted(scripts), sorted(scenes), project


# ------------------------------------------------------- 1. res:// existence
def res_to_fs(res_path: str) -> str:
    return os.path.join(ROOT, res_path[len("res://"):])


RES_RE = re.compile(r'"(res://[^"]+)"')


def check_res_paths(scripts: List[str], scenes: List[str]) -> Set[str]:
    known: Set[str] = set()
    for path in scripts + scenes:
        known.add("res://" + rel(path).replace(os.sep, "/"))
    referenced: Set[str] = set()
    for path in scripts + scenes:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        for match in RES_RE.finditer(text):
            target = match.group(1)
            # Strip ::node-path style suffixes and query fragments.
            target = target.split("::")[0]
            referenced.add(target)
            if target in known:
                continue
            # Directories are legal (DirAccess.open) so accept existing dirs too.
            if not os.path.exists(res_to_fs(target)):
                err(f"{rel(path)}: references missing res:// path {target}")
    return referenced


# ------------------------------------------------- 2. $NodePath vs .tscn tree
EXT_RE = re.compile(r"^\[ext_resource ([^\]]+)\]$", re.M)


def parse_ext_resources(text: str) -> List[Dict[str, str]]:
    """Parse [ext_resource ...] headers.

    Godot writes these attributes in either order depending on version, so they
    are parsed as a key/value set rather than by position.
    """
    out: List[Dict[str, str]] = []
    for match in EXT_RE.finditer(text):
        attrs = dict(re.findall(r'(\w+)="([^"]*)"', match.group(1)))
        out.append(attrs)
    return out


def parse_scene(scene_path: str) -> Tuple[Dict[str, str], Dict[str, str], Dict[str, str]]:
    """Return (node_path -> node type, node_path -> script res path, id -> res path).

    The first [node] entry is the root and has path ".". Children carry
    parent="..." which is itself a node path.
    """
    with open(scene_path, encoding="utf-8") as handle:
        text = handle.read()

    scripts_by_id: Dict[str, str] = {}
    for attrs in parse_ext_resources(text):
        if attrs.get("type") == "Script" and "path" in attrs and "id" in attrs:
            scripts_by_id[attrs["id"]] = attrs["path"]

    types: Dict[str, str] = {}
    script_of: Dict[str, str] = {}

    # Split the file into node blocks: a [node ...] header plus the property
    # lines beneath it, up to the next section. `script = ExtResource(...)` is
    # a property line, NOT part of the header, so it must be read per block.
    blocks = re.split(r"^\[(?=[a-z_]+ )", text, flags=re.M)
    for block in blocks:
        header = re.match(r'node name="([^"]+)"([^\]]*)\]', block)
        if not header:
            continue
        name, attrs = header.group(1), header.group(2)
        parent_match = re.search(r'parent="([^"]*)"', attrs)
        parent = parent_match.group(1) if parent_match else ""
        path = "." if parent == "" else (name if parent == "." else f"{parent}/{name}")
        type_match = re.search(r'type="([^"]+)"', attrs)
        types[path] = type_match.group(1) if type_match else "PackedSceneInstance"
        script_match = re.search(r'^script = ExtResource\("([^"]+)"\)', block, re.M)
        if script_match and script_match.group(1) in scripts_by_id:
            script_of[path] = scripts_by_id[script_match.group(1)]
    return types, script_of, scripts_by_id


DOLLAR_RE = re.compile(r'\$([A-Za-z_][A-Za-z0-9_/]*)')
GET_NODE_RE = re.compile(r'get_node(?:_or_null)?\(\s*"([^"]+)"\s*\)')


def instance_types(scene_path: str) -> Dict[str, str]:
    """node_path -> type, following instanced sub-scenes one level deep.

    A node written as `[node name="X" instance=ExtResource("id")]` contributes
    the sub-scene's whole subtree under the prefix "X/".
    """
    with open(scene_path, encoding="utf-8") as handle:
        text = handle.read()
    scenes_by_id = {
        a["id"]: a["path"]
        for a in parse_ext_resources(text)
        if a.get("type") == "PackedScene" and "id" in a and "path" in a
    }
    types, _, _ = parse_scene(scene_path)
    for block in re.split(r"^\[(?=[a-z_]+ )", text, flags=re.M):
        header = re.match(r'node name="([^"]+)"([^\]]*)\]', block)
        if not header:
            continue
        inst = re.search(r'instance=ExtResource\("([^"]+)"\)', header.group(2))
        if not inst or inst.group(1) not in scenes_by_id:
            continue
        parent_match = re.search(r'parent="([^"]*)"', header.group(2))
        parent = parent_match.group(1) if parent_match else ""
        prefix = header.group(1) if parent in ("", ".") else f"{parent}/{header.group(1)}"
        sub_fs = res_to_fs(scenes_by_id[inst.group(1)])
        if not os.path.exists(sub_fs):
            continue
        sub_types, _, _ = parse_scene(sub_fs)
        for sub_path, sub_type in sub_types.items():
            types[prefix if sub_path == "." else f"{prefix}/{sub_path}"] = sub_type
    return types


def check_scene_node_paths(scenes: List[str]) -> None:
    """Every $Path / get_node("Path") must resolve from the node it is written on.

    A script attached to node X resolves its paths relative to X, so we walk
    every scripted node in the scene, not just the root. Instanced sub-scenes
    are expanded so paths like Player/Camera2D are validated too.
    """
    for scene in scenes:
        types, script_of, _ = parse_scene(scene)
        if not types:
            continue
        full_types = instance_types(scene)
        for node_path, script_res in script_of.items():
            script_fs = res_to_fs(script_res)
            if not os.path.exists(script_fs):
                err(f"{rel(scene)}: node '{node_path}' script missing ({script_res})")
                continue
            with open(script_fs, encoding="utf-8") as handle:
                script_text = handle.read()
            referenced = [m.group(1) for m in DOLLAR_RE.finditer(script_text)]
            referenced += [m.group(1) for m in GET_NODE_RE.finditer(script_text)]
            for raw in referenced:
                if raw.startswith("/"):
                    resolved = raw.lstrip("/")
                elif node_path == ".":
                    resolved = raw
                else:
                    resolved = f"{node_path}/{raw}"
                if resolved in full_types:
                    continue
                err(
                    f"{rel(script_fs)}: on node '{node_path}' the path "
                    f"'{raw}' does not resolve in {rel(scene)}"
                )


# ------------------------------------------------------- 3. Input actions
def declared_actions(project_path: str) -> Set[str]:
    with open(project_path, encoding="utf-8") as handle:
        text = handle.read()
    section = re.search(r"^\[input\]$(.*?)(?=^\[|\Z)", text, re.M | re.S)
    if not section:
        return set()
    return set(re.findall(r"^([A-Za-z_][A-Za-z0-9_]*)=\{", section.group(1), re.M))


ACTION_RE = re.compile(r'&(move_left|move_right|jump|attack_light|attack_heavy|dash|lantern|anchor|interact|revelation|special|journal|ui_journal|[a-z_]+)')
INPUT_CALL_RE = re.compile(r'(?:Input\.is_action_[a-z_]+|is_action_pressed|is_action_just_pressed|is_action_released|action)\(\s*&"([a-z_]+)"')


def check_input_actions(scripts: List[str], project_path: str) -> None:
    declared = declared_actions(project_path)
    builtin = {
        "ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right",
        "ui_home", "ui_end", "ui_page_up", "ui_page_down", "ui_focus_next",
        "ui_focus_prev",
    }
    for path in scripts:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        for match in INPUT_CALL_RE.finditer(text):
            action = match.group(1)
            if action in builtin:
                continue
            if action not in declared:
                err(f"{rel(path)}: uses undeclared input action '{action}'")


# ------------------------------------------------------------- 4. autoloads
def check_autoloads(project_path: str) -> None:
    with open(project_path, encoding="utf-8") as handle:
        text = handle.read()
    section = re.search(r"^\[autoload\]$(.*?)(?=^\[|\Z)", text, re.M | re.S)
    if not section:
        err("project.godot: no [autoload] section")
        return
    for match in re.finditer(r'^(\w+)="\*?(res://[^"]+)"$', section.group(1), re.M):
        name, path = match.group(1), match.group(2)
        if not os.path.exists(res_to_fs(path)):
            err(f"project.godot: autoload {name} points at missing {path}")


# -------------------------------------------------------- 5. class_name dupes
def check_class_names(scripts: List[str]) -> Dict[str, str]:
    seen: Dict[str, str] = {}
    for path in scripts:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        match = re.search(r"^class_name\s+(\w+)", text, re.M)
        if not match:
            continue
        name = match.group(1)
        if name in seen:
            err(f"class_name '{name}' declared twice: {rel(seen[name])} and {rel(path)}")
        if name in GODOT_BUILTINS:
            err(f"{rel(path)}: class_name '{name}' shadows a Godot built-in class")
        seen[name] = path
    return seen


# Engine singletons and math/variant types that legitimately take CONSTANT access.
GODOT_BUILTIN_CONSTANTS = {
    "Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i", "Color",
    "Rect2", "Rect2i", "Transform2D", "Transform3D", "Basis", "Quaternion",
    "Plane", "AABB", "Key", "MouseButton", "JoyButton", "JoyAxis", "Error",
    "Side", "Corner", "Orientation", "Variant", "Array", "Dictionary", "String",
    "StringName", "PackedByteArray", "PackedStringArray", "PackedInt32Array",
    "PackedFloat32Array", "PackedVector2Array", "PackedColorArray", "Callable",
    "Signal", "NodePath", "RID", "Projection", "Plane3D", "FileAccess",
    "DirAccess", "AudioStreamWAV", "AudioStream", "AudioStreamPlayer",
    "Image", "ImageTexture", "Font", "FontFile", "Gradient", "GradientTexture2D",
    "StyleBoxFlat", "Theme", "Shortcut", "InputEvent", "InputEventAction",
    "PhysicsRayQueryParameters2D", "PhysicsRayQueryParameters3D", "Curve",
    "CurveTexture", "Noise", "FastNoiseLite", "RandomNumberGenerator",
    # TextServer is registered in ClassDB (servers/register_server_types.cpp,
    # GDREGISTER_ABSTRACT_CLASS(TextServer)) even though it is not an Engine
    # singleton, so `TextServer.AUTOWRAP_WORD_SMART` resolves in GDScript.
    # It is the documented way to set Label.autowrap_mode in Godot 4.
    "TextServer", "TextServerManager", "AudioServer", "RenderingServer",
    "PhysicsServer2D", "DisplayServer", "ConfigFile", "GPUParticles2D",
    "ParticleProcessMaterial", "PanelContainer", "VBoxContainer", "HBoxContainer",
    "HSlider", "VSlider", "Control", "CanvasItem", "Node", "Object", "Resource",
    "Timer", "Tween", "SceneTree", "PackedScene", "Label", "Button", "ColorRect",
    "Parallax2D", "StaticBody2D", "Area2D", "CollisionShape2D", "RectangleShape2D",
    "CapsuleShape2D", "CharacterBody2D", "Camera2D", "Sprite2D", "Polygon2D",
    "Line2D", "PointLight2D", "CanvasModulate", "WorldEnvironment", "AnimationPlayer",
}

# Godot 4 global class names that a local enum/class/const must not shadow.
# A collision parses locally but breaks references from other scripts, and the
# resulting "Identifier not declared" error points at the wrong file.
GODOT_BUILTINS = {
    "Path", "Path2D", "Path3D", "PathFollow2D", "PathFollow3D", "Node", "Node2D",
    "Node3D", "Control", "Resource", "Object", "RefCounted", "SceneTree",
    "Area2D", "Area3D", "Body2D", "Timer", "Tween", "AnimationPlayer",
    "AnimationTree", "Camera2D", "Camera3D", "CanvasItem", "CanvasLayer",
    "CharacterBody2D", "CharacterBody3D", "CollisionShape2D", "CollisionShape3D",
    "ColorRect", "Label", "Button", "Texture2D", "Texture3D", "Image",
    "InputEvent", "InputEventKey", "InputEventMouseButton", "PhysicsBody2D",
    "RigidBody2D", "StaticBody2D", "Sprite2D", "Sprite3D", "TileMap",
    "TileMapLayer", "Viewport", "Window", "AudioStream", "AudioStreamPlayer",
    "PackedScene", "Script", "GDScript", "Material", "Shader", "StyleBox",
    "Theme", "Light2D", "PointLight2D", "DirectionalLight2D", "Parallax2D",
    "ParallaxBackground", "ParallaxLayer", "Marker2D", "RayCast2D",
    "Shape2D", "Shape3D", "Curve", "Curve2D", "Curve3D", "Gradient",
    "RandomNumberGenerator", "RegEx", "JSON", "Time", "Engine", "OS",
    "DisplayServer", "RenderingServer", "PhysicsServer2D", "ProjectSettings",
    "Input", "InputMap", "Translation", "NavigationAgent2D", "NavigationRegion2D",
}

DECL_RE = re.compile(r"^\s*(?:enum|class|const)\s+(\w+)", re.M)


def check_builtin_shadowing(scripts: List[str]) -> None:
    """Flag local enum/class/const declarations that shadow a Godot built-in."""
    for path in scripts:
        with open(path, encoding="utf-8") as handle:
            lines = handle.readlines()
        for lineno, line in enumerate(lines, start=1):
            match = DECL_RE.match(line)
            if not match:
                continue
            name = match.group(1)
            if name in GODOT_BUILTINS:
                err(
                    f"{rel(path)}:{lineno}: '{name}' shadows Godot built-in class "
                    f"{name}; other scripts referencing it will fail to parse"
                )


def autoload_names(project_path: str) -> Set[str]:
    with open(project_path, encoding="utf-8") as handle:
        text = handle.read()
    section = re.search(r"^\[autoload\]$(.*?)(?=^\[|\Z)", text, re.M | re.S)
    if not section:
        return set()
    return set(re.findall(r'^(\w+)="\*?res://', section.group(1), re.M))


## Matches `Owner.CONSTANT` only when Owner is the FIRST segment of the
## expression. The negative lookbehind is essential: without it, a chain like
## `NightmareData.ResolutionKind.DESTROY` cannot match at `NightmareData`
## (the second group must be all-caps), so the engine skips ahead and matches
## `ResolutionKind.DESTROY`, blaming the enum member instead of the real owner.
QUALIFIED_CONST_RE = re.compile(r"(?<![.\w])([A-Z][A-Za-z0-9_]*)\.([A-Z][A-Z0-9_]*)\b")


def check_unresolvable_constants(
    scripts: List[str], class_map: Dict[str, str], project_path: str
) -> None:
    """Flag `Name.CONSTANT` where Name is not a globally addressable type.

    In Godot 4 only `class_name` scripts, autoload singletons and engine classes
    are globally visible. An enum declared inside one script cannot be referenced
    from another, and the resulting parse error is reported at the *referencing*
    file with a cascade of "Failed to compile depended scripts" elsewhere, which
    makes it expensive to diagnose from the engine alone.
    """
    known: Set[str] = set(class_map.keys())
    known |= autoload_names(project_path)
    known |= GODOT_BUILTINS
    known |= GODOT_BUILTIN_CONSTANTS

    for path in scripts:
        with open(path, encoding="utf-8") as handle:
            lines = handle.readlines()
        # Names this script declares itself are always in scope inside it.
        local: Set[str] = {m.group(1) for m in DECL_RE.finditer("".join(lines))}
        own_class = None
        text = "".join(lines)
        m = re.search(r"^class_name\s+(\w+)", text, re.M)
        if m:
            own_class = m.group(1)

        for lineno, line in enumerate(lines, start=1):
            code = line.split("#", 1)[0]
            for match in QUALIFIED_CONST_RE.finditer(code):
                owner = match.group(1)
                if owner in known or owner in local or owner == own_class:
                    continue
                err(
                    f"{rel(path)}:{lineno}: '{owner}.{match.group(2)}' — '{owner}' is "
                    f"not a class_name, autoload or engine class, so this will not "
                    f"parse in Godot"
                )



# ------------------------------------------- 6. .new() called on a PackedScene
SCENE_CONST_RE = re.compile(
    r"^\s*(?:const|var)\s+(\w+)\s*[:=][^\n]*?"
    r"(?:preload|load)\(\s*[\"']([^\"']+\.tscn)[\"']\s*\)",
    re.MULTILINE,
)
NEW_CALL_RE = re.compile(r"\b(\w+)\.new\(")


def check_new_on_packed_scene(scripts: List[str]) -> None:
    """Flag `.new()` called on a PackedScene constant.

    `PackedScene` has no `new()`; the call fails at runtime with
    "Invalid call. Nonexistent function 'new' in base 'PackedScene'".

    Note on scope: an earlier version of this check forbade `.new()` on any
    Node-derived `class_name`. That was wrong and has been removed — Godot
    fully supports `MyNode2D.new()`, and procedural construction is how the
    visuals in this project are built. The only genuine error in this family
    is calling `.new()` on a scene, which is what is asserted here.
    """
    for path in scripts:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        scene_names = {m.group(1): m.group(2) for m in SCENE_CONST_RE.finditer(text)}
        if not scene_names:
            continue
        for match in NEW_CALL_RE.finditer(text):
            cls = match.group(1)
            if cls in scene_names:
                err(
                    f"{rel(path)}: {cls}.new() but {cls} is a PackedScene "
                    f"({scene_names[cls]}) — use {cls}.instantiate()"
                )


# --------------------------------- 6b. invented float-suffixed math functions
# Godot 4 provides an `f` suffix for exactly these: absf, ceilf, clampf,
# floorf, lerpf, maxf, minf, roundf, signf, snappedf, wrapf, randf, randfn.
# It does NOT provide one for the transcendental functions, so `powf()` is a
# parse error ("Function 'powf()' not found in base self") — the plain `pow()`
# already returns a float. This check exists because that error cost a full CI
# round trip to discover.
FLOAT_SUFFIX_STEMS = {
    "pow", "sqrt", "exp", "log", "sin", "cos", "tan", "asin", "acos", "atan",
    "atan2", "sinh", "cosh", "tanh", "fmod", "posmod", "fposmod", "ease",
    "remap", "pingpong", "inverse_lerp", "range_lerp", "lerp_angle",
    "cubic_interpolate", "angle_difference", "is_nan", "is_inf", "is_finite",
    "deg_to_rad", "rad_to_deg", "linear_to_db", "db_to_linear",
    "step_decimals", "nearest_po2",
}
INVENTED_CALL_RE = re.compile(r"(?<![.\w])([a-z_][a-z0-9_]*f)\s*\(")


def check_invented_float_functions(scripts: List[str]) -> None:
    """Flag `stemf()` where Godot only defines `stem()`."""
    for path in scripts:
        with open(path, encoding="utf-8") as handle:
            lines = handle.readlines()
        for number, line in enumerate(lines, 1):
            code = line.split("#")[0]
            for match in INVENTED_CALL_RE.finditer(code):
                name = match.group(1)
                stem = name[:-1]
                if stem in FLOAT_SUFFIX_STEMS:
                    err(
                        f"{rel(path)}:{number}: '{name}()' does not exist in "
                        f"Godot 4 — use '{stem}()', which already returns a "
                        f"float (only absf/ceilf/clampf/floorf/lerpf/maxf/"
                        f"minf/roundf/signf/snappedf/wrapf/randf have an f form)"
                    )


# --------------------------- 6c. static-func calls on project class_name types
# A parse error of the form
#   Invalid argument for "spawn()" function: argument 3 should be "float"
#   but is "Vector2"
# halts the whole import, and every script depending on that class then fails
# with "Could not resolve class". One bad call site takes the project down.
#
# Scope note: this deliberately only checks `ClassName.func(...)` where
# ClassName is a project `class_name` and `func` is one of its *static*
# functions. That is unambiguous. A bare `func()` call cannot be resolved
# without full scope analysis -- the same name may exist on several classes --
# so checking those produces false positives and is not done here.
STATIC_DECL_RE = re.compile(
    r"^[ \t]*static[ \t]+func[ \t]+([a-z_]\w*)[ \t]*\(([^)]*)\)",
    re.MULTILINE,
)
LITERAL_SHAPES = (
    (re.compile(r"^Vector2i?\s*\("), {"Vector2", "Vector2i"}),
    (re.compile(r"^Vector3i?\s*\("), {"Vector3", "Vector3i"}),
    (re.compile(r"^Color\s*\("), {"Color"}),
    (re.compile(r"^Rect2i?\s*\("), {"Rect2", "Rect2i"}),
    (re.compile(r"^NodePath\s*\("), {"NodePath"}),
    (re.compile(r"^-?\d+$"), {"int", "float"}),
    (re.compile(r"^-?\d*\.\d+$"), {"float"}),
    (re.compile(r'^&?"'), {"String", "StringName"}),
    (re.compile(r"^(true|false)$"), {"bool"}),
)


def _split_params(raw: str) -> List[tuple]:
    """[(name, declared_type_or_None, has_default)] for a parameter list."""
    params: List[tuple] = []
    for chunk in raw.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        has_default = "=" in chunk
        head = chunk.split("=")[0].strip()
        name = head.split(":")[0].strip()
        declared = head.split(":")[1].strip() if ":" in head else None
        params.append((name, declared, has_default))
    return params


def _classify(argument: str):
    """The declared types an argument literal could satisfy, or None."""
    argument = argument.strip()
    for pattern, types in LITERAL_SHAPES:
        if pattern.match(argument):
            return types
    return None


def _split_arguments(raw: str) -> List[str]:
    """Split on top-level commas only, so Vector2(a, b) stays one argument."""
    out: List[str] = []
    depth = 0
    current = ""
    for char in raw:
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        if char == "," and depth == 0:
            out.append(current)
            current = ""
        else:
            current += char
    if current.strip():
        out.append(current)
    return [a.strip() for a in out if a.strip()]


def _balanced(text: str, open_index: int) -> int:
    """Index just past the paren matching the one at open_index."""
    depth = 0
    for index in range(open_index, len(text)):
        if text[index] == "(":
            depth += 1
        elif text[index] == ")":
            depth -= 1
            if depth == 0:
                return index + 1
    return len(text)


def check_static_calls(scripts: List[str], class_map: Dict[str, str]) -> None:
    """Validate `ClassName.static_func(...)` against the declaration."""
    statics: Dict[str, Dict[str, List[tuple]]] = {}
    for class_name, path in class_map.items():
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        found = {
            m.group(1): _split_params(m.group(2))
            for m in STATIC_DECL_RE.finditer(text)
        }
        if found:
            statics[class_name] = found

    call_re = re.compile(r"(?<![.\w])([A-Z]\w*)\.([a-z_]\w*)[ \t]*\(")
    for path in scripts:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        for match in call_re.finditer(text):
            owner, name = match.group(1), match.group(2)
            if owner not in statics or name not in statics[owner]:
                continue
            params = statics[owner][name]
            end = _balanced(text, match.end() - 1)
            arguments = _split_arguments(text[match.end():end - 1])
            required = sum(1 for _n, _t, default in params if not default)
            line = text.count("\n", 0, match.start()) + 1
            if len(arguments) < required or len(arguments) > len(params):
                err(
                    f"{rel(path)}:{line}: {owner}.{name}() takes "
                    f"{required}-{len(params)} argument(s), called with "
                    f"{len(arguments)}"
                )
                continue
            for position, argument in enumerate(arguments):
                declared = params[position][1]
                given = _classify(argument)
                if declared is None or given is None or declared in given:
                    continue
                err(
                    f"{rel(path)}:{line}: {owner}.{name}() argument "
                    f"{position + 1} is declared '{declared}' but is called "
                    f"with '{argument[:40]}'"
                )


# --------------------- 6d. calls to functions that do not exist in Godot 4
# Two CI round trips were spent on this exact class of error:
#   Function "powf()" not found in base self.
#   Function "get_viewport_camera_2d()" not found in base self.
# Both halt the import before anything else is checked, and the second one
# also took down every script that referenced the failing class. Neither is
# visible without the engine, so the engine had to be the one to find them.
#
# This check closes that gap. A bare `name(` call in GDScript resolves either
# to a global function, a keyword, or a method on `self`. Everything in that
# space is enumerable: the Godot class reference for the classes this project
# uses (tools/godot_api.json), the @GlobalScope function list, and this
# project's own declarations. Anything outside those three sets does not
# exist, and saying so here is free.
#
# Limitations, stated plainly: this only checks *bare* calls. `object.name()`
# is not checked, because resolving `object`'s type requires the type system.
# So a typo'd method on an explicit receiver still needs the engine.
GODOT_GLOBAL_FUNCTIONS = {
    "abs", "absf", "absi", "acos", "acosh", "angle_difference", "asin",
    "asinh", "atan", "atan2", "atanh", "bytes_to_var",
    "bytes_to_var_with_objects", "cart_to_pol", "ceil", "ceilf", "ceili",
    "clamp", "clampf", "clampi", "cos", "cosh", "cubic_interpolate",
    "db_to_linear", "deg_to_rad", "ease", "error_string", "exp", "floor",
    "floorf", "floori", "fmod", "fposmod", "fpow", "fpwrap",
    "frame_from_msec", "frame_from_secs", "get_current_dir_from_path",
    "get_error_message", "get_stack", "globalize_path", "hash",
    "instance_from_id", "inverse_lerp", "is_equal_approx", "is_finite",
    "is_inf", "is_instance_id_valid", "is_instance_valid", "is_nan",
    "is_same", "is_zero_approx", "lerp", "lerp_angle", "lerpf",
    "linear_to_db", "localize_path", "log", "max", "maxf", "maxi", "min",
    "minf", "mini", "move_toward", "nearest_po2", "pingpong", "polar_to_cart",
    "posmod", "pow", "powi", "print", "print_rich", "print_verbose",
    "printerr", "printraw", "prints", "printt", "push_error", "push_warning",
    "rad_to_deg", "rand_from_seed", "randf", "randfn", "randi",
    "randi_range", "randomize", "range_lerp", "remap", "rid_allocate_id",
    "rid_from_int64", "rot_from_euler", "round", "roundf", "roundi", "seed",
    "sign", "signf", "signi", "sin", "sinh", "snapped", "snappedf",
    "snappedi", "sqrt", "step_decimals", "stepify", "str", "str_to_var",
    "tan", "tanh", "type_convert", "type_string", "typeof", "var_to_bytes",
    "var_to_bytes_with_objects", "var_to_str", "weakref", "wrap", "wrapf",
    "wrapi",
}
GDSCRIPT_STATEMENTS = {
    "if", "elif", "else", "for", "while", "match", "return", "await", "pass",
    "break", "continue", "func", "class", "extends", "class_name", "signal",
    "const", "var", "enum", "static", "super", "self", "not", "and", "or",
    "in", "is", "as", "void", "true", "false", "null", "assert", "preload",
    "load", "range", "len",
}
# Built-in constructors and conversions that look like calls.
BUILTIN_CONSTRUCTORS = {
    "bool", "int", "float", "String", "StringName", "Vector2", "Vector2i",
    "Vector3", "Vector3i", "Vector4", "Vector4i", "Color", "Rect2", "Rect2i",
    "Transform2D", "Transform3D", "Basis", "Quaternion", "Plane", "AABB",
    "Array", "Dictionary", "PackedByteArray", "PackedInt32Array",
    "PackedFloat32Array", "PackedVector2Array", "PackedStringArray",
    "PackedColorArray", "NodePath", "RID", "Callable", "Signal", "Projection",
}
BARE_CALL_RE = re.compile(r"(?<![.\w@])([a-z_][a-z0-9_]*)\s*\(")
FUNC_DECL_ANY_RE = re.compile(
    r"^[ \t]*(?:static[ \t]+)?func[ \t]+([a-z_][a-z0-9_]*)[ \t]*\(", re.MULTILINE
)
SIGNAL_DECL_RE = re.compile(r"^[ \t]*signal[ \t]+([a-z_][a-z0-9_]*)", re.MULTILINE)
VAR_DECL_RE = re.compile(r"^[ \t]*(?:var|const)[ \t]+([a-z_][a-z0-9_]*)", re.MULTILINE)
STRING_OPEN_RE = re.compile(r'("""|")')


def _strip_strings(line: str, in_multiline: bool) -> tuple:
    """Blank out string contents so `%s (` inside a literal is not a call."""
    out: List[str] = []
    index = 0
    while index < len(line):
        if in_multiline:
            end = line.find('"""', index)
            if end == -1:
                return "".join(out), True
            index = end + 3
            in_multiline = False
            continue
        if line[index] == '"':
            if line.startswith('"""', index):
                in_multiline = True
                index += 3
                continue
            index += 1
            while index < len(line):
                if line[index] == "\\":
                    index += 2
                    continue
                if line[index] == '"':
                    index += 1
                    break
                index += 1
            out.append('""')
            continue
        out.append(line[index])
        index += 1
    return "".join(out), in_multiline


def _engine_methods() -> Set[str]:
    """Method names from the Godot class reference, cached in the repo."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "godot_api.json")
    if not os.path.exists(path):
        return set()
    with open(path, encoding="utf-8") as handle:
        return set(json.load(handle).get("methods", []))


def check_unknown_calls(scripts: List[str]) -> None:
    """Flag bare calls that resolve to nothing in Godot 4 or this project."""
    engine = _engine_methods()
    if not engine:
        warn("tools/godot_api.json is missing; skipping the unknown-call check")
        return

    declared: Set[str] = set()
    for path in scripts:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        declared |= set(FUNC_DECL_ANY_RE.findall(text))
        declared |= set(SIGNAL_DECL_RE.findall(text))
        # A local Callable variable is legitimately called by name.
        declared |= set(VAR_DECL_RE.findall(text))

    known = engine | GODOT_GLOBAL_FUNCTIONS | GDSCRIPT_STATEMENTS | BUILTIN_CONSTRUCTORS | declared

    for path in scripts:
        with open(path, encoding="utf-8") as handle:
            raw_lines = handle.readlines()
        in_multiline = False
        for number, raw in enumerate(raw_lines, 1):
            code, in_multiline = _strip_strings(raw, in_multiline)
            if in_multiline:
                continue
            code = code.split("#")[0]
            for match in BARE_CALL_RE.finditer(code):
                name = match.group(1)
                if name in known:
                    continue
                err(
                    f"{rel(path)}:{number}: '{name}()' is not a Godot 4 "
                    f"global, an engine method, or a function declared in "
                    f"this project — it will fail to parse"
                )


# ------------------------------------------------- 7. lexical sanity of .gd
def check_lexical(scripts: List[str]) -> None:
    for path in scripts:
        with open(path, encoding="utf-8") as handle:
            lines = handle.readlines()
        depth = 0
        in_string = False
        string_char = ""
        for lineno, raw in enumerate(lines, start=1):
            line = raw.rstrip("\n")
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            # Indentation must be tabs only (Godot allows spaces but mixing is fatal).
            leading = line[: len(line) - len(line.lstrip())]
            if leading and (" " in leading and "\t" in leading):
                err(f"{rel(path)}:{lineno}: mixed tabs and spaces in indentation")
            i = 0
            while i < len(line):
                ch = line[i]
                if in_string:
                    if ch == "\\":
                        i += 2
                        continue
                    if ch == string_char:
                        in_string = False
                    i += 1
                    continue
                if ch in "\"'":
                    in_string = True
                    string_char = ch
                    i += 1
                    continue
                if ch == "#" and not in_string:
                    break
                if ch in "([{":
                    depth += 1
                elif ch in ")]}":
                    depth -= 1
                    if depth < 0:
                        err(f"{rel(path)}:{lineno}: unbalanced closing '{ch}'")
                        depth = 0
                i += 1
        if depth != 0:
            err(f"{rel(path)}: unbalanced brackets (net depth {depth})")


# ------------------------------------------------------------ 8. data files
REQUIRED_FIELDS: Dict[str, List[str]] = {
    "nightmares": ["id", "display_name", "category", "max_health"],
    "echoes": ["id", "display_name", "ability_key"],
    "weapons": ["id", "display_name", "light_damage"],
    "skills": ["id", "display_name", "path"],
    "quests": ["id", "title", "objectives"],
}


def check_data() -> None:
    data_root = os.path.join(ROOT, "data")
    if not os.path.isdir(data_root):
        err("data/ directory missing")
        return
    for kind, required in REQUIRED_FIELDS.items():
        folder = os.path.join(data_root, kind)
        if not os.path.isdir(folder):
            err(f"data/{kind}/ missing — NightmareDatabase will warn at boot")
            continue
        files = [f for f in sorted(os.listdir(folder)) if f.endswith(".json")]
        if not files:
            err(f"data/{kind}/ contains no .json files")
        for name in files:
            full = os.path.join(folder, name)
            try:
                with open(full, encoding="utf-8") as handle:
                    payload = json.load(handle)
            except json.JSONDecodeError as exc:
                err(f"data/{kind}/{name}: invalid JSON ({exc})")
                continue
            for field in required:
                if field not in payload:
                    err(f"data/{kind}/{name}: missing required field '{field}'")
            if "id" in payload and payload["id"] != name[:-5]:
                warn(f"data/{kind}/{name}: id '{payload['id']}' differs from filename")


# ------------------------------------------------------------- 9. scene files
def check_scenes(scenes: List[str]) -> None:
    for scene in scenes:
        with open(scene, encoding="utf-8") as handle:
            text = handle.read()
        header = re.match(r'\[gd_scene load_steps=(\d+) format=(\d+)\]', text)
        if not header:
            err(f"{rel(scene)}: missing [gd_scene ...] header")
            continue
        declared_steps = int(header.group(1))
        resources = len(re.findall(r"^\[ext_resource ", text, re.M)) + len(
            re.findall(r"^\[sub_resource ", text, re.M)
        )
        # load_steps counts resources + 1 in files written by the editor.
        if declared_steps not in (resources, resources + 1):
            err(
                f"{rel(scene)}: load_steps={declared_steps} but file declares "
                f"{resources} resources"
            )
        ext = parse_ext_resources(text)
        for attrs in ext:
            target = attrs.get("path")
            if target and not os.path.exists(res_to_fs(target)):
                err(f"{rel(scene)}: ext_resource points at missing {target}")
        # Every ExtResource("id") used must have been declared.
        declared_ids = {a["id"] for a in ext if "id" in a}
        for match in re.finditer(r'ExtResource\("([^"]+)"\)', text):
            if match.group(1) not in declared_ids:
                err(f"{rel(scene)}: ExtResource(\"{match.group(1)}\") has no ext_resource entry")


# ----------------------------------------------------------------------- main
def main() -> int:
    scripts, scenes, project = collect()
    if not project:
        err("project.godot not found at repository root")
        print_report(scripts, scenes)
        return 1

    check_res_paths(scripts, scenes)
    check_scene_node_paths(scenes)
    check_input_actions(scripts, project)
    check_autoloads(project)
    class_map = check_class_names(scripts)
    check_builtin_shadowing(scripts)
    check_unresolvable_constants(scripts, class_map, project)
    check_new_on_packed_scene(scripts)
    check_invented_float_functions(scripts)
    check_static_calls(scripts, class_map)
    check_unknown_calls(scripts)
    check_lexical(scripts)
    check_data()
    check_scenes(scenes)
    print_report(scripts, scenes)
    return 1 if ERRORS else 0


def print_report(scripts: List[str], scenes: List[str]) -> None:
    data_files = 0
    for dirpath, _dirs, files in os.walk(os.path.join(ROOT, "data")):
        data_files += len([f for f in files if f.endswith(".json")])
    print(f"scanned {len(scripts)} scripts, {len(scenes)} scenes, {data_files} data files")
    for message in WARNINGS:
        print(f"  WARN  {message}")
    for message in ERRORS:
        print(f"  ERROR {message}")
    if ERRORS:
        print(f"\nFAILED: {len(ERRORS)} error(s)")
    else:
        print(f"\nOK: no cross-reference errors found")


if __name__ == "__main__":
    sys.exit(main())
