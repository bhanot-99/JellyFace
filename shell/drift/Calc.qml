pragma Singleton

import QtQuick
import Quickshell

// Maths and unit conversion for the command bar. A small parser (no eval): + - * / ^ % and brackets, "x" or "×" for
// times, sqrt sin cos tan asin acos atan ln log abs round floor ceil, pi and e. Units: "5 km in mi", "70 f to c",
// "2 h in min", "500 mb in gb" (length, mass, temperature, time, data, speed, area, volume).
Singleton {
    id: root

    // returns the result as text, or "" when the query is not maths
    function evaluate(q: string): string {
        const s = q.trim().replace(/^=\s*/, "").replace(/×/g, "*").replace(/÷/g, "/").replace(/(\d)\s*x\s*(?=[\d(])/gi, "$1*").replace(/,/g, "");
        // needs an operator or a function, and nothing but maths
        if (!/^[\d\s.+\-*/^%()a-z]+$/i.test(s) || !/[+\-*/^%(]|sqrt|sin|cos|tan|log|ln|abs|round|floor|ceil/i.test(s) || /^\s*-?\d+(\.\d+)?\s*$/.test(s))
            return "";
        try {
            const v = parse(s);
            if (!isFinite(v))
                return "";
            return format(v);
        } catch (e) {
            return "";
        }
    }

    function format(v: real): string {
        if (Math.abs(v) >= 1e15 || (Math.abs(v) < 1e-6 && v !== 0))
            return v.toExponential(6).replace(/\.?0+e/, "e");
        return String(Math.round(v * 1e10) / 1e10);
    }

    function parse(src: string): real {
        const tokens = src.match(/\d*\.\d+|\d+|[a-z]+|[+\-*/^%()]/gi) ?? [];
        let i = 0;
        const peek = () => tokens[i];
        const next = () => tokens[i++];
        const fns = {
            sqrt: Math.sqrt, sin: Math.sin, cos: Math.cos, tan: Math.tan, asin: Math.asin, acos: Math.acos, atan: Math.atan,
            ln: Math.log, log: Math.log10, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil
        };
        const consts = { pi: Math.PI, e: Math.E };

        function expr() {
            let v = term();
            while (peek() === "+" || peek() === "-")
                v = next() === "+" ? v + term() : v - term();
            return v;
        }
        function term() {
            let v = factor();
            while (peek() === "*" || peek() === "/" || peek() === "%" || (peek() === "(" ) || (peek() && /^[a-z]/i.test(peek()))) {
                const op = peek();
                if (op === "*" || op === "/" || op === "%") {
                    next();
                    const r = factor();
                    v = op === "*" ? v * r : op === "/" ? v / r : v % r;
                } else {
                    v = v * factor(); // implicit: 2(3), 2pi
                }
            }
            return v;
        }
        function factor() {
            const b = unary();
            if (peek() === "^") {
                next();
                return Math.pow(b, factor());
            }
            return b;
        }
        function unary() {
            if (peek() === "-") {
                next();
                return -unary();
            }
            if (peek() === "+") {
                next();
                return unary();
            }
            return atom();
        }
        function atom() {
            const t = next();
            if (t === undefined)
                throw "end";
            if (t === "(") {
                const v = expr();
                if (next() !== ")")
                    throw "bracket";
                return v;
            }
            if (/^[\d.]/.test(t))
                return parseFloat(t);
            const name = t.toLowerCase();
            if (name in consts)
                return consts[name];
            if (name in fns)
                return fns[name](factor());
            throw "name";
        }

        const v = expr();
        if (i < tokens.length)
            throw "trailing";
        return v;
    }

    // ── units ──
    readonly property var units: ({
            // length, metres
            mm: ["length", 0.001, "millimetres"], cm: ["length", 0.01, "centimetres"], m: ["length", 1, "metres"],
            km: ["length", 1000, "kilometres"], in: ["length", 0.0254, "inches"], ft: ["length", 0.3048, "feet"],
            yd: ["length", 0.9144, "yards"], mi: ["length", 1609.344, "miles"],
            // mass, kilograms
            mg: ["mass", 1e-6, "milligrams"], g: ["mass", 0.001, "grams"], kg: ["mass", 1, "kilograms"],
            t: ["mass", 1000, "tonnes"], oz: ["mass", 0.028349523125, "ounces"], lb: ["mass", 0.45359237, "pounds"],
            // time, seconds
            ms: ["time", 0.001, "milliseconds"], s: ["time", 1, "seconds"], min: ["time", 60, "minutes"],
            h: ["time", 3600, "hours"], d: ["time", 86400, "days"], wk: ["time", 604800, "weeks"],
            // data, bytes
            b: ["data", 1, "bytes"], kb: ["data", 1e3, "kilobytes"], mb: ["data", 1e6, "megabytes"], gb: ["data", 1e9, "gigabytes"],
            tb: ["data", 1e12, "terabytes"], kib: ["data", 1024, "kibibytes"], mib: ["data", 1048576, "mebibytes"],
            gib: ["data", 1073741824, "gibibytes"],
            // speed, m/s
            kmh: ["speed", 1 / 3.6, "km/h"], mph: ["speed", 0.44704, "mph"], mps: ["speed", 1, "m/s"], kn: ["speed", 0.514444, "knots"],
            // area, m²
            m2: ["area", 1, "square metres"], km2: ["area", 1e6, "square kilometres"], ha: ["area", 1e4, "hectares"],
            acre: ["area", 4046.8564224, "acres"], ft2: ["area", 0.09290304, "square feet"],
            // volume, litres
            ml: ["volume", 0.001, "millilitres"], l: ["volume", 1, "litres"], gal: ["volume", 3.785411784, "US gallons"],
            cup: ["volume", 0.2365882365, "cups"], floz: ["volume", 0.0295735295625, "fluid ounces"],
            // temperature (special)
            c: ["temp", 0, "°C"], f: ["temp", 0, "°F"], k: ["temp", 0, "kelvin"]
        })
    readonly property var aliases: ({
            metre: "m", meter: "m", metres: "m", meters: "m", kilometre: "km", kilometer: "km", kilometres: "km", kilometers: "km",
            mile: "mi", miles: "mi", foot: "ft", feet: "ft", inch: "in", inches: "in", yard: "yd", yards: "yd",
            gram: "g", grams: "g", kilo: "kg", kilos: "kg", kilogram: "kg", kilograms: "kg", pound: "lb", pounds: "lb", lbs: "lb",
            ounce: "oz", ounces: "oz", sec: "s", secs: "s", second: "s", seconds: "s", mins: "min", minute: "min", minutes: "min",
            hr: "h", hrs: "h", hour: "h", hours: "h", day: "d", days: "d", week: "wk", weeks: "wk",
            "km/h": "kmh", kph: "kmh", "m/s": "mps", knots: "kn", litre: "l", liter: "l", litres: "l", liters: "l",
            gallon: "gal", gallons: "gal", cups: "cup", celsius: "c", "°c": "c", fahrenheit: "f", "°f": "f", kelvin: "k",
            "m²": "m2", "km²": "km2", sqft: "ft2", acres: "acre", hectare: "ha", hectares: "ha"
        })

    function unit(name: string): string {
        const n = name.toLowerCase();
        return units[n] ? n : aliases[n] ?? "";
    }

    // "5 km in mi" -> {value: "3.107 mi", detail: "5 kilometres"}, or null
    function convert(q: string): var {
        const m = q.trim().match(/^(-?[\d.,]+)\s*([a-z°²/]+)\s+(?:in|to|as|=)\s+([a-z°²/]+)$/i);
        if (!m)
            return null;
        const v = parseFloat(m[1].replace(/,/g, ""));
        const a = unit(m[2]), b = unit(m[3]);
        if (!a || !b || isNaN(v) || units[a][0] !== units[b][0])
            return null;
        let out;
        if (units[a][0] === "temp") {
            const k = a === "c" ? v + 273.15 : a === "f" ? (v - 32) * 5 / 9 + 273.15 : v;
            out = b === "c" ? k - 273.15 : b === "f" ? (k - 273.15) * 9 / 5 + 32 : k;
        } else {
            out = v * units[a][1] / units[b][1];
        }
        const shown = Math.abs(out) >= 100 ? Math.round(out * 100) / 100 : Math.round(out * 1000) / 1000;
        const label = units[b][0] === "temp" ? units[b][2] : b;
        return {
            value: `${shown} ${label}`,
            raw: String(shown),
            detail: `${v} ${units[a][2]}`
        };
    }
}
