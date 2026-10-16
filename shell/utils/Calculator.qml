pragma Singleton

import QtQuick
import Quickshell

// Safe math expression and unit converter engine for search bars (Raycast / Spotlight style)
Singleton {
    id: root

    readonly property var _units: ({
        // Length (base meter)
        "m": 1, "meter": 1, "meters": 1,
        "km": 1000, "kilometer": 1000, "kilometers": 1000,
        "cm": 0.01, "centimeter": 0.01, "centimeters": 0.01,
        "mm": 0.001, "millimeter": 0.001, "millimeters": 0.001,
        "mi": 1609.344, "mile": 1609.344, "miles": 1609.344,
        "yd": 0.9144, "yard": 0.9144, "yards": 0.9144,
        "ft": 0.3048, "foot": 0.3048, "feet": 0.3048,
        "in": 0.0254, "inch": 0.0254, "inches": 0.0254,
        // Mass (base gram)
        "g": 1, "gram": 1, "grams": 1,
        "kg": 1000, "kilogram": 1000, "kilograms": 1000,
        "mg": 0.001, "milligram": 0.001, "milligrams": 0.001,
        "lb": 453.59237, "lbs": 453.59237, "pound": 453.59237, "pounds": 453.59237,
        "oz": 28.3495, "ounce": 28.3495, "ounces": 28.3495,
        // Data (base byte)
        "b": 1, "byte": 1, "bytes": 1,
        "kb": 1024, "mb": 1048576, "gb": 1073741824, "tb": 1099511627776
    })

    function tryConvert(raw: string): var {
        const str = raw.trim();
        const m = str.match(/^([\d.xXabcdefABCDEF]+)\s*([a-zA-Z]+)?\s+(?:to|in)\s+([a-zA-Z]+)$/i);
        if (!m)
            return null;

        const numStr = m[1];
        const val = numStr.toLowerCase().startsWith("0x") ? parseInt(numStr, 16) : parseFloat(numStr);
        if (isNaN(val))
            return null;

        const fromUnit = (m[2] || "").toLowerCase();
        const toUnit = m[3].toLowerCase();

        // Base conversions
        if (toUnit === "hex") {
            const hex = Math.round(val).toString(16).toUpperCase();
            return {
                title: `= 0x${hex}`,
                subtext: `${numStr} in hexadecimal`,
                copyValue: `0x${hex}`
            };
        }
        if (toUnit === "bin" || toUnit === "binary") {
            const bin = Math.round(val).toString(2);
            return {
                title: `= 0b${bin}`,
                subtext: `${numStr} in binary`,
                copyValue: `0b${bin}`
            };
        }
        if (toUnit === "dec" || toUnit === "decimal") {
            return {
                title: `= ${val}`,
                subtext: `${numStr} in decimal`,
                copyValue: `${val}`
            };
        }

        // Temperature
        if ((fromUnit === "c" || fromUnit === "celsius") && (toUnit === "f" || toUnit === "fahrenheit")) {
            const res = (val * 9 / 5 + 32).toFixed(2);
            return {
                title: `= ${res} °F`,
                subtext: `${val} °C in Fahrenheit`,
                copyValue: `${res}`
            };
        }
        if ((fromUnit === "f" || fromUnit === "fahrenheit") && (toUnit === "c" || toUnit === "celsius")) {
            const res = ((val - 32) * 5 / 9).toFixed(2);
            return {
                title: `= ${res} °C`,
                subtext: `${val} °F in Celsius`,
                copyValue: `${res}`
            };
        }

        // Standard unit lookup
        if (_units[fromUnit] && _units[toUnit]) {
            const converted = (val * _units[fromUnit]) / _units[toUnit];
            const formatted = Math.abs(converted - Math.round(converted)) < 1e-6 ? Math.round(converted).toString() : parseFloat(converted.toFixed(4)).toString();
            return {
                title: `= ${formatted} ${m[3]}`,
                subtext: `${val} ${m[2]} in ${m[3]}`,
                copyValue: formatted
            };
        }
        return null;
    }

    function tryMath(raw: string): var {
        const str = raw.trim();
        // Check if string contains at least one math operator or Math function
        if (!/[\d\s+\-*/%^().,eE]|sqrt|abs|round|floor|ceil|sin|cos|tan|pi/.test(str))
            return null;
        // Must contain at least one operator to distinguish from plain numbers
        if (!/[+\-*/%^]|\b(sqrt|sin|cos|tan|abs|round|floor|ceil)\b/.test(str))
            return null;
        // Disallow dangerous characters
        if (/[^0-9a-zA-Z\s+\-*/%^().,]/i.test(str))
            return null;

        // Replace convenient operators
        const expr = str.replace(/\^/g, "**").replace(/\bpi\b/gi, "Math.PI").replace(/\be\b/gi, "Math.E").replace(/\bsqrt\(/gi, "Math.sqrt(").replace(/\babs\(/gi, "Math.abs(").replace(/\bround\(/gi, "Math.round(").replace(/\bfloor\(/gi, "Math.floor(").replace(/\bceil\(/gi, "Math.ceil(").replace(/\bsin\(/gi, "Math.sin(").replace(/\bcos\(/gi, "Math.cos(").replace(/\btan\(/gi, "Math.tan(");

        // Sanity check: only allowed tokens: numbers, Math.<fn>, +, -, *, /, %, (, ), .
        const sanitized = expr.replace(/Math\.(PI|E|sqrt|abs|round|floor|ceil|sin|cos|tan)/g, "");
        if (/[a-zA-Z_$]/.test(sanitized))
            return null;

        try {
            const fn = new Function(`"use strict"; return (${expr});`);
            const val = fn();
            if (typeof val === "number" && !isNaN(val) && isFinite(val)) {
                const formatted = Math.abs(val - Math.round(val)) < 1e-6 ? Math.round(val).toString() : parseFloat(val.toFixed(6)).toString();
                return {
                    title: `= ${formatted}`,
                    subtext: `${raw.trim()}`,
                    copyValue: formatted
                };
            }
        } catch (e) {
            return null;
        }
        return null;
    }

    function evaluate(raw: string): var {
        if (!raw || raw.trim().length === 0)
            return null;

        const conv = tryConvert(raw);
        if (conv)
            return conv;

        return tryMath(raw);
    }
}
