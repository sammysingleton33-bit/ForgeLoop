// AI Kingdoms icon set (FORGE-03). 48x48 flat icons with a dark ink outline, drawn by hand in SVG.
// Used directly by the HTML prototypes; export-icons.js writes icons/<name>.svg and icons/png/<name>.png
// (128 px) for upload to Roblox (asset request: production/handoffs/2026-10-12-forge-03-to-user-ui-icons.md).
// Until uploaded, Luau falls back to the glyph listed in games/sandbox/config/UITheme.luau.
(function (root) {
	const O = "#24190E"; // outline ink
	const SW = 2.2; // outline width
	const s = (extra = "") => `stroke="${O}" stroke-width="${SW}" stroke-linejoin="round" stroke-linecap="round" ${extra}`;

	const grainHead = `
		<ellipse cx="24" cy="7.5" rx="2.6" ry="4.3" fill="#F3D57E" ${s('stroke-width="1.6"')}/>
		<ellipse cx="21.2" cy="12" rx="2.5" ry="4" fill="#F3D57E" transform="rotate(-28 21.2 12)" ${s('stroke-width="1.6"')}/>
		<ellipse cx="26.8" cy="12" rx="2.5" ry="4" fill="#F3D57E" transform="rotate(28 26.8 12)" ${s('stroke-width="1.6"')}/>
		<ellipse cx="21.2" cy="17.4" rx="2.5" ry="4" fill="#E9C25C" transform="rotate(-28 21.2 17.4)" ${s('stroke-width="1.6"')}/>
		<ellipse cx="26.8" cy="17.4" rx="2.5" ry="4" fill="#E9C25C" transform="rotate(28 26.8 17.4)" ${s('stroke-width="1.6"')}/>`;
	const stalk = `<path d="M24 44 L24 20" fill="none" stroke="${O}" stroke-width="4.2" stroke-linecap="round"/>
		<path d="M24 44 L24 20" fill="none" stroke="#9CC95A" stroke-width="2" stroke-linecap="round"/>`;

	const log = (cx, cy) => `
		<circle cx="${cx}" cy="${cy}" r="9" fill="#7E5230" ${s()}/>
		<circle cx="${cx}" cy="${cy}" r="6.3" fill="#EDC28C"/>
		<circle cx="${cx}" cy="${cy}" r="3.6" fill="none" stroke="#B9824B" stroke-width="1.4"/>
		<circle cx="${cx}" cy="${cy}" r="1.1" fill="#9A6537"/>`;

	const icons = {
		food: `<g transform="rotate(-24 24 44)">${stalk}${grainHead}</g>
			<g transform="rotate(24 24 44)">${stalk}${grainHead}</g>
			${stalk}${grainHead}
			<rect x="18.5" y="32" width="11" height="5" rx="2" fill="#C4844C" ${s('stroke-width="1.8"')}/>`,
		wood: `${log(15, 33)}${log(33, 33)}${log(24, 17)}`,
		stone: `
			<rect x="5" y="27" width="18" height="14" rx="2.5" fill="#A7B6C8" ${s()}/>
			<rect x="25" y="27" width="18" height="14" rx="2.5" fill="#97A7BB" ${s()}/>
			<rect x="14" y="12" width="20" height="15" rx="2.5" fill="#B9C6D5" ${s()}/>
			<path d="M7.5 30.5 H20.5 M27.5 30.5 H40.5 M16.5 15.5 H31.5" stroke="#DCE4EE" stroke-width="2" stroke-linecap="round"/>
			<path d="M30 35 L33 37.5 L32 40" fill="none" stroke="#5E6B7C" stroke-width="1.4" stroke-linecap="round"/>`,
		gold: `
			<ellipse cx="19" cy="38" rx="13" ry="4.6" fill="#B8862C" ${s()}/>
			<ellipse cx="19" cy="34" rx="13" ry="4.6" fill="#D9A63A" ${s()}/>
			<ellipse cx="19" cy="30" rx="13" ry="4.6" fill="#E8B947" ${s()}/>
			<circle cx="31" cy="22" r="11.5" fill="#F2C447" ${s()}/>
			<circle cx="31" cy="22" r="8" fill="none" stroke="#B8862C" stroke-width="1.6"/>
			<path d="M25.8 25.5 L25 18 L28.4 21 L31 16.5 L33.6 21 L37 18 L36.2 25.5 Z" fill="#FBE29A" stroke="#9C7022" stroke-width="1.3" stroke-linejoin="round"/>`,
		citizens: `
			<circle cx="31" cy="14" r="6" fill="#CDBD96" ${s()}/>
			<path d="M20.5 36 C21 26 26 22.5 31 22.5 C36 22.5 41 26 41.5 36 Z" fill="#B9A67A" ${s()}/>
			<circle cx="18" cy="18" r="7" fill="#EADCBA" ${s()}/>
			<path d="M5.5 42 C6 31 12 27 18 27 C24 27 30 31 30.5 42 Z" fill="#E6D7B5" ${s()}/>`,
		crown: `
			<path d="M8 33 L6 14 L16 23 L24 9 L32 23 L42 14 L40 33 Z" fill="#F2C447" ${s()}/>
			<rect x="7.5" y="32" width="33" height="8" rx="2" fill="#D6A84A" ${s()}/>
			<circle cx="6" cy="13" r="2.8" fill="#D9573F" ${s('stroke-width="1.6"')}/>
			<circle cx="24" cy="8.5" r="2.8" fill="#D9573F" ${s('stroke-width="1.6"')}/>
			<circle cx="42" cy="13" r="2.8" fill="#D9573F" ${s('stroke-width="1.6"')}/>
			<circle cx="16" cy="36" r="1.8" fill="#4E8BD0"/><circle cx="24" cy="36" r="1.8" fill="#D9573F"/><circle cx="32" cy="36" r="1.8" fill="#4E8BD0"/>`,
		build: `<g transform="rotate(-40 24 24)">
			<rect x="21.5" y="16" width="5" height="30" rx="2" fill="#A0683A" ${s()}/>
			<rect x="11" y="6" width="26" height="11" rx="2.5" fill="#A9B7C8" ${s()}/>
			<rect x="11" y="6" width="7" height="11" rx="2" fill="#7D8DA2" ${s()}/>
			<path d="M14 9 H35" stroke="#DCE4EE" stroke-width="1.6" stroke-linecap="round"/></g>`,
		kingdom: `
			<rect x="5" y="17" width="11" height="26" fill="#D9CDB0" ${s()}/>
			<rect x="32" y="17" width="11" height="26" fill="#D9CDB0" ${s()}/>
			<rect x="15" y="23" width="18" height="20" fill="#E8DEC6" ${s()}/>
			<path d="M5 17 V12 H8 V15 H10 V12 H13 V15 H16 V12 V17 M32 17 V12 H35 V15 H37 V12 H40 V15 H43 V12 V17" fill="#D9CDB0" ${s()}/>
			<path d="M20 43 V35 A4 4 0 0 1 28 35 V43 Z" fill="#3A2A1A" ${s('stroke-width="1.8"')}/>
			<path d="M24 23 V8" stroke="${O}" stroke-width="2"/><path d="M24 8 L33 11 L24 14 Z" fill="#D9573F" ${s('stroke-width="1.6"')}/>
			<rect x="8.5" y="22" width="4" height="6" rx="2" fill="#3A2A1A"/><rect x="35.5" y="22" width="4" height="6" rx="2" fill="#3A2A1A"/>`,
		army: `
			<g transform="rotate(45 24 24)"><rect x="22" y="2" width="4.5" height="30" rx="1.5" fill="#CBD5E1" ${s()}/>
			<rect x="16" y="31" width="16.5" height="4" rx="1.5" fill="#D6A84A" ${s()}/><rect x="22" y="35" width="4.5" height="7" fill="#7E5230" ${s()}/>
			<circle cx="24.25" cy="44" r="2.4" fill="#D6A84A" ${s('stroke-width="1.6"')}/></g>
			<g transform="rotate(-45 24 24)"><rect x="21.5" y="2" width="4.5" height="30" rx="1.5" fill="#DCE4EE" ${s()}/>
			<rect x="15.5" y="31" width="16.5" height="4" rx="1.5" fill="#D6A84A" ${s()}/><rect x="21.5" y="35" width="4.5" height="7" fill="#7E5230" ${s()}/>
			<circle cx="23.75" cy="44" r="2.4" fill="#D6A84A" ${s('stroke-width="1.6"')}/></g>`,
		standings: `
			<path d="M14 7 H34 V17 C34 25 29.5 29 24 29 C18.5 29 14 25 14 17 Z" fill="#F2C447" ${s()}/>
			<path d="M14 11 H7 C7 19 10 22 15 22 M34 11 H41 C41 19 38 22 33 22" fill="none" ${s()}/>
			<rect x="21" y="29" width="6" height="7" fill="#D6A84A" ${s()}/>
			<rect x="14" y="36" width="20" height="7" rx="2" fill="#8A5A32" ${s()}/>
			<path d="M19 11 V18" stroke="#FBE29A" stroke-width="2.4" stroke-linecap="round"/>`,
		timer: `
			<rect x="10" y="5" width="28" height="5" rx="2" fill="#8A5A32" ${s()}/>
			<rect x="10" y="38" width="28" height="5" rx="2" fill="#8A5A32" ${s()}/>
			<path d="M14 10 H34 C34 18 27 21 27 24 C27 27 34 30 34 38 H14 C14 30 21 27 21 24 C21 21 14 18 14 10 Z" fill="#DDEBF5" ${s()}/>
			<path d="M17.5 13 H30.5 C29.5 17 26 19.5 24 21.5 C22 19.5 18.5 17 17.5 13 Z" fill="#E8B947"/>
			<path d="M24 26 V35 M17 36 C19 33 29 33 31 36 Z" fill="#E8B947" stroke="#E8B947" stroke-width="1.6"/>`,
		lock: `
			<path d="M15 22 V15 A9 9 0 0 1 33 15 V22" fill="none" stroke="${O}" stroke-width="7"/>
			<path d="M15 22 V15 A9 9 0 0 1 33 15 V22" fill="none" stroke="#A9B7C8" stroke-width="3.2"/>
			<rect x="9" y="21" width="30" height="22" rx="4" fill="#D6A84A" ${s()}/>
			<circle cx="24" cy="30" r="3.2" fill="#3A2A1A"/><rect x="22.6" y="31" width="2.8" height="7" rx="1" fill="#3A2A1A"/>`,
		check: `<circle cx="24" cy="24" r="18" fill="#5BAE5F" ${s()}/><path d="M15 24.5 L21.5 31 L33.5 17.5" fill="none" stroke="#F7EFDC" stroke-width="4.4" stroke-linecap="round" stroke-linejoin="round"/>`,
		cross: `<circle cx="24" cy="24" r="18" fill="#D9573F" ${s()}/><path d="M17 17 L31 31 M31 17 L17 31" stroke="#F7EFDC" stroke-width="4.4" stroke-linecap="round"/>`,
		close: `<path d="M13 13 L35 35 M35 13 L13 35" stroke="${O}" stroke-width="8" stroke-linecap="round"/><path d="M13 13 L35 35 M35 13 L13 35" stroke="#EAC46C" stroke-width="4" stroke-linecap="round"/>`,
		plus: `<path d="M24 11 V37 M11 24 H37" stroke="${O}" stroke-width="8.5" stroke-linecap="round"/><path d="M24 11 V37 M11 24 H37" stroke="#F7EFDC" stroke-width="4.5" stroke-linecap="round"/>`,
		minus: `<path d="M11 24 H37" stroke="${O}" stroke-width="8.5" stroke-linecap="round"/><path d="M11 24 H37" stroke="#F7EFDC" stroke-width="4.5" stroke-linecap="round"/>`,
		info: `<circle cx="24" cy="24" r="18" fill="#4E8BD0" ${s()}/><circle cx="24" cy="15" r="2.8" fill="#F7EFDC"/><rect x="21.5" y="20.5" width="5" height="15" rx="2" fill="#F7EFDC"/>`,
		warning: `<path d="M24 6 L43 40 H5 Z" fill="#E8A23A" ${s()}/><rect x="21.6" y="17" width="4.8" height="13" rx="2" fill="#2A2116"/><circle cx="24" cy="35" r="2.6" fill="#2A2116"/>`,
		townhall: `
			<rect x="8" y="23" width="32" height="20" fill="#E3D7BA" ${s()}/>
			<path d="M4.5 24 L24 9.5 L43.5 24 Z" fill="#B8402E" ${s()}/>
			<path d="M20 43 V34 A4 4 0 0 1 28 34 V43 Z" fill="#5A3A22" ${s('stroke-width="1.8"')}/>
			<rect x="11.5" y="28" width="5" height="6" rx="1" fill="#4E8BD0" ${s('stroke-width="1.5"')}/>
			<rect x="31.5" y="28" width="5" height="6" rx="1" fill="#4E8BD0" ${s('stroke-width="1.5"')}/>
			<path d="M24 10 V2.5" stroke="${O}" stroke-width="2"/><path d="M24 2.5 L32 5 L24 7.5 Z" fill="#EAC46C" ${s('stroke-width="1.4"')}/>
			<circle cx="24" cy="19" r="3" fill="#EAC46C" ${s('stroke-width="1.5"')}/>`,
		house: `
			<rect x="31" y="11" width="5" height="9" fill="#8C8C8C" ${s('stroke-width="1.8"')}/>
			<rect x="11" y="24" width="26" height="18" fill="#EADCBA" ${s()}/>
			<path d="M7 26 L24 11 L41 26 Z" fill="#A9743F" ${s()}/>
			<path d="M11.5 22 L24 13.5 L36.5 22" fill="none" stroke="#C99A5E" stroke-width="1.6"/>
			<rect x="15" y="31" width="7" height="11" rx="1" fill="#6E4A2C" ${s('stroke-width="1.6"')}/>
			<rect x="26" y="29" width="7" height="6" rx="1" fill="#F2C447" ${s('stroke-width="1.6"')}/>`,
		storehouse: `
			<rect x="7" y="22" width="34" height="21" fill="#C4844C" ${s()}/>
			<path d="M4.5 23 L24 10 L43.5 23 Z" fill="#6E4A2C" ${s()}/>
			<rect x="16" y="27" width="16" height="16" fill="#9A5F32" ${s()}/>
			<path d="M16 27 L32 43 M32 27 L16 43" stroke="${O}" stroke-width="1.8"/>
			<path d="M11 26 V40 M37 26 V40" stroke="#A86E3D" stroke-width="2"/>`,
		farm: `
			<path d="M3 41 H45 V45 H3 Z" fill="#8DBF4B" ${s()}/>
			<path d="M19 41 L21.5 19 H28.5 L31 41 Z" fill="#EADCBA" ${s()}/>
			<path d="M19.5 20 L25 13 L30.5 20 Z" fill="#B8402E" ${s()}/>
			<rect x="23" y="32" width="4.5" height="9" rx="1" fill="#6E4A2C"/>
			<g transform="rotate(20 25 17)"><rect x="23.4" y="1" width="3.2" height="32" rx="1" fill="#C4844C" ${s('stroke-width="1.6"')}/>
			<rect x="9" y="15.4" width="32" height="3.2" rx="1" fill="#C4844C" ${s('stroke-width="1.6"')}/></g>
			<circle cx="25" cy="17" r="2.6" fill="#EAC46C" ${s('stroke-width="1.5"')}/>`,
		lumbercamp: `
			<path d="M11 28 V40 C11 43 37 43 37 40 V28" fill="#8A5A32" ${s()}/>
			<ellipse cx="24" cy="28" rx="13" ry="5" fill="#EDC28C" ${s()}/>
			<ellipse cx="24" cy="28" rx="7.5" ry="2.7" fill="none" stroke="#B9824B" stroke-width="1.4"/>
			<g transform="rotate(-35 24 24)"><rect x="22.5" y="2" width="4.5" height="26" rx="1.5" fill="#B07A45" ${s()}/>
			<path d="M27 4 C35 4 37 10 37 14 C33 13 29 13 27 13 Z" fill="#B9C6D5" ${s()}/></g>`,
		quarry: `
			<path d="M4 43 L10 27 L19 21 L31 23 L40 30 L44 43 Z" fill="#9FB0C4" ${s()}/>
			<path d="M10 27 L17 31 L19 21 M17 31 L30 33 L31 23 M30 33 L40 30" fill="none" stroke="#6F7E92" stroke-width="1.5"/>
			<g transform="rotate(32 24 18)"><rect x="22" y="6" width="4" height="27" rx="1.5" fill="#B07A45" ${s()}/>
			<path d="M8 11 C14 4 34 4 40 11 C33 9 15 9 8 11 Z" fill="#DCE4EE" ${s()}/></g>`,
		goldmine: `
			<path d="M6 43 V18 L24 8 L42 18 V43 Z" fill="#7E5230" ${s()}/>
			<path d="M13 43 V25 A11 11 0 0 1 35 25 V43 Z" fill="#1E1611" ${s()}/>
			<path d="M11 21 H37" stroke="#B07A45" stroke-width="3.2"/>
			<path d="M15 43 L17 37 L22 36 L23 43 Z M24 43 L27 36.5 L32 38 L33 43 Z" fill="#F2C447" ${s('stroke-width="1.6"')}/>`,
		barracks: `
			<rect x="6" y="22" width="36" height="21" fill="#D9CDB0" ${s()}/>
			<path d="M3.5 23 L12 12 H36 L44.5 23 Z" fill="#3F72B5" ${s()}/>
			<path d="M16 26 H32 V33 C32 38 28 41 24 42.5 C20 41 16 38 16 33 Z" fill="#B8402E" ${s()}/>
			<path d="M24 27 V41 M17 32 H31" stroke="#EAC46C" stroke-width="2"/>`,
		watchtower: `
			<path d="M15 44 L18 18 H30 L33 44 Z" fill="#D9CDB0" ${s()}/>
			<path d="M12 18 V11 H15.5 V14 H19 V11 H22.5 V14 H25.5 V11 H29 V14 H32.5 V11 H36 V18 Z" fill="#C9BEA0" ${s()}/>
			<rect x="22" y="23" width="4" height="8" rx="2" fill="#3A2A1A"/>
			<path d="M24 11 V3" stroke="${O}" stroke-width="2"/><path d="M24 3 L31 5.5 L24 8 Z" fill="#B8402E" ${s('stroke-width="1.4"')}/>`,
		militia: `
			<path d="M33 3 L36 9 L34.4 9 L34.4 44 H31.6 V9 H30 Z" fill="#B07A45" ${s('stroke-width="1.8"')}/>
			<path d="M33 3 L37 11 H29 Z" fill="#DCE4EE" ${s('stroke-width="1.8"')}/>
			<circle cx="19" cy="27" r="13" fill="#B8402E" ${s()}/>
			<circle cx="19" cy="27" r="9" fill="none" stroke="#EAC46C" stroke-width="2"/>
			<circle cx="19" cy="27" r="3" fill="#EAC46C" ${s('stroke-width="1.5"')}/>`,
		archer: `
			<path d="M14 5 C34 12 34 36 14 43" fill="none" stroke="${O}" stroke-width="6" stroke-linecap="round"/>
			<path d="M14 5 C34 12 34 36 14 43" fill="none" stroke="#B07A45" stroke-width="3" stroke-linecap="round"/>
			<path d="M14 5 V43" stroke="#F7EFDC" stroke-width="1.4"/>
			<path d="M8 24 H38" stroke="${O}" stroke-width="2.4"/>
			<path d="M38 24 L32 20.5 V27.5 Z" fill="#DCE4EE" ${s('stroke-width="1.5"')}/>
			<path d="M8 24 L4 20.5 M8 24 L4 27.5 M11 24 L7 20.5 M11 24 L7 27.5" stroke="#B8402E" stroke-width="2" stroke-linecap="round"/>`,
		knight: `
			<path d="M11 40 V20 C11 11 17 6 24 6 C31 6 37 11 37 20 V40 Z" fill="#B9C6D5" ${s()}/>
			<path d="M11 22 H37 M11 27 H37" stroke="${O}" stroke-width="1.6"/>
			<rect x="14" y="22" width="20" height="5" fill="#1E1611"/>
			<path d="M24 6 V40" stroke="#8494A8" stroke-width="2"/>
			<path d="M24 6 C26 1 35 1 40 5 C34 5 30 7 27 10" fill="#D9573F" ${s('stroke-width="1.8"')}/>
			<circle cx="17" cy="33" r="1.4" fill="${O}"/><circle cx="31" cy="33" r="1.4" fill="${O}"/>`,
		banner: `
			<path d="M8 6 H40" stroke="${O}" stroke-width="5" stroke-linecap="round"/><path d="M8 6 H40" stroke="#B07A45" stroke-width="2.4" stroke-linecap="round"/>
			<path d="M12 7 H36 V43 L24 35 L12 43 Z" fill="#3E8A4B" ${s()}/>
			<path d="M15 10 H33" stroke="#EAC46C" stroke-width="2"/>
			<circle cx="24" cy="21" r="5.5" fill="#EAC46C" ${s('stroke-width="1.6"')}/>`,
		crest: `
			<path d="M8 7 H40 V22 C40 33 32 40 24 44 C16 40 8 33 8 22 Z" fill="#3F72B5" ${s()}/>
			<path d="M24 7 V44 M8 21 H40" stroke="#EAC46C" stroke-width="2.4"/>
			<path d="M8 7 H24 V21 H8 Z M24 21 H40 V22 C40 33 32 40 24 44 Z" fill="#B8402E" opacity="0.92"/>
			<path d="M8 7 H40 V22 C40 33 32 40 24 44 C16 40 8 33 8 22 Z" fill="none" ${s()}/>`,
		chest: `
			<path d="M6 21 C6 12 12 8 24 8 C36 8 42 12 42 21 Z" fill="#9A5F32" ${s()}/>
			<rect x="6" y="21" width="36" height="20" rx="2" fill="#B07A45" ${s()}/>
			<path d="M13 9.5 V41 M35 9.5 V41" stroke="#D6A84A" stroke-width="3.2"/>
			<rect x="20" y="17" width="8" height="10" rx="1.5" fill="#EAC46C" ${s('stroke-width="1.6"')}/>`,
		keep: `
			<path d="M10 44 V18 H14 V14 H18 V18 H22 V14 H26 V18 H30 V14 H34 V18 H38 V44 Z" fill="#BDB295" ${s()}/>
			<path d="M10 26 H38 M10 34 H38 M18 18 V26 M30 18 V26 M14 26 V34 M24 26 V34 M34 26 V34" stroke="#8F866E" stroke-width="1.4"/>
			<path d="M19 44 V36 C19 32.5 29 32.5 29 36 V44 Z" fill="#5A3B24" ${s('stroke-width="1.8"')}/>
			<path d="M24 14 V3" stroke="${O}" stroke-width="2"/>
			<path d="M24 3.5 L34 6.5 L24 9.5 Z" fill="#B8402E" ${s('stroke-width="1.6"')}/>`,
		wall: `
			<path d="M4 40 V20 H9 V15 H15 V20 H21 V15 H27 V20 H33 V15 H39 V20 H44 V40 Z" fill="#B3AA92" ${s()}/>
			<path d="M4 27 H44 M4 34 H44 M12 20 V27 M24 20 V27 M36 20 V27 M8 27 V34 M18 27 V34 M30 27 V34 M40 27 V34 M14 34 V40 M26 34 V40 M36 34 V40" stroke="#857D68" stroke-width="1.4"/>`,
		gate: `
			<path d="M4 44 V12 H8 V9 H12 V12 H16 V44 Z M32 44 V12 H36 V9 H40 V12 H44 V44 Z" fill="#BDB295" ${s()}/>
			<path d="M16 44 V24 C16 14 32 14 32 24 V44 Z" fill="#A69C82" ${s()}/>
			<path d="M19 44 V25 C19 18.5 29 18.5 29 25 V44 Z" fill="#3B2A1C" ${s('stroke-width="1.6"')}/>
			<path d="M21.5 21 V44 M24 19.5 V44 M26.5 21 V44 M19 28 H29 M19 34 H29 M19 40 H29" stroke="#8F8A80" stroke-width="1.5"/>`,
		rotate: `
			<path d="M36 17 A14 14 0 1 0 38 28" fill="none" stroke="${O}" stroke-width="8" stroke-linecap="round"/>
			<path d="M36 17 A14 14 0 1 0 38 28" fill="none" stroke="#EAC46C" stroke-width="4" stroke-linecap="round"/>
			<path d="M28.5 15.5 L39.5 9 L40 21.5 Z" fill="#EAC46C" ${s()}/>`,
		emblem_flame: `
			<path d="M24 44 C13 44 8 36 10 27 C11.5 21 16 18 16 11 C21 14 23 18 22.5 23 C25 20 26.5 14 26 6 C33 11 40 19 38.5 30 C37.5 38 32 44 24 44 Z" fill="#E0642F" ${s()}/>
			<path d="M24 41 C19 41 16.5 37.5 17.5 33 C18.5 29.5 21.5 28 22 24.5 C25 26.5 26 29 25.5 31.5 C27.5 30.5 28.5 28.5 28.5 26 C31.5 29 32.5 33 31.5 36 C30.5 39.5 27.5 41 24 41 Z" fill="#F6C24A"/>`,
		emblem_star: `
			<path d="M24 4 L29.2 17.6 L43.6 18.2 L32.4 27.4 L36.2 41.4 L24 33.4 L11.8 41.4 L15.6 27.4 L4.4 18.2 L18.8 17.6 Z" fill="#DCE8F5" ${s()}/>
			<path d="M24 11 L27.2 19.8 L24 30 L20.8 19.8 Z" fill="#9FC0E6"/>`,
		emblem_oak: `
			<path d="M24 45 V31" stroke="${O}" stroke-width="4.4" stroke-linecap="round"/>
			<path d="M24 45 V31" stroke="#7E5230" stroke-width="2" stroke-linecap="round"/>
			<path d="M24 4 C28 6 27 10 30 11 C34 11 35 14 33 17 C37 18 38 22 35 24 C38 27 36 31 32 30 C30 33 26 33 24 31 C22 33 18 33 16 30 C12 31 10 27 13 24 C10 22 11 18 15 17 C13 14 14 11 18 11 C21 10 20 6 24 4 Z" fill="#5DAE4F" ${s()}/>
			<path d="M24 9 V31 M24 15 L29 13 M24 15 L19 13 M24 21 L31 19 M24 21 L17 19 M24 26 L29 25 M24 26 L19 25" stroke="#2F6B30" stroke-width="1.5" stroke-linecap="round"/>`,
		emblem_sun: `
			<g fill="#F2C447" ${s('stroke-width="1.8"')}>
				<path d="M24 2 L27 10 H21 Z"/><path d="M24 46 L21 38 H27 Z"/><path d="M2 24 L10 21 V27 Z"/><path d="M46 24 L38 27 V21 Z"/>
				<path d="M8.4 8.4 L16 12.2 L12.2 16 Z"/><path d="M39.6 39.6 L32 35.8 L35.8 32 Z"/><path d="M39.6 8.4 L35.8 16 L32 12.2 Z"/><path d="M8.4 39.6 L12.2 32 L16 35.8 Z"/>
			</g>
			<circle cx="24" cy="24" r="11" fill="#F6D16A" ${s()}/>
			<circle cx="24" cy="24" r="6.5" fill="#FBE6A2"/>`,
		// FL-0088 citizen card and conversation (appended).
		talk: `
			<path d="M9 7 H39 Q44 7 44 12 V29 Q44 34 39 34 H23 L12.5 42.5 L14.5 34 H9 Q4 34 4 29 V12 Q4 7 9 7 Z" fill="#F7EFDC" ${s()}/>
			<circle cx="15" cy="20.5" r="2.8" fill="#8F6A26"/><circle cx="24" cy="20.5" r="2.8" fill="#8F6A26"/><circle cx="33" cy="20.5" r="2.8" fill="#8F6A26"/>`,
		heart: `
			<path d="M24 42.5 C10.5 33 4 25.5 4 16.8 C4 10.6 8.7 6 14.4 6 C18.5 6 21.9 8.4 24 12 C26.1 8.4 29.5 6 33.6 6 C39.3 6 44 10.6 44 16.8 C44 25.5 37.5 33 24 42.5 Z" fill="#D9573F" ${s()}/>
			<path d="M11.5 15 C12.2 12.3 14.2 10.8 16.8 10.7" fill="none" stroke="#F4A08E" stroke-width="2.6" stroke-linecap="round"/>`,
		mood: `
			<circle cx="24" cy="24" r="19" fill="#F2C447" ${s()}/>
			<circle cx="17.5" cy="19.5" r="2.6" fill="${O}"/><circle cx="30.5" cy="19.5" r="2.6" fill="${O}"/>
			<path d="M15 28 Q24 37 33 28" fill="none" stroke="${O}" stroke-width="2.8" stroke-linecap="round"/>
			<path d="M11 15 Q13 10.5 17.5 9" fill="none" stroke="#FBE6A2" stroke-width="2.4" stroke-linecap="round"/>`,
		scroll: `
			<rect x="11" y="9" width="26" height="30" fill="#EADCBA" ${s()}/>
			<rect x="7" y="5" width="34" height="7.5" rx="3.75" fill="#D6C295" ${s()}/>
			<rect x="7" y="35.5" width="34" height="7.5" rx="3.75" fill="#D6C295" ${s()}/>
			<path d="M16 18.5 H32 M16 24 H32 M16 29.5 H27" stroke="#8F6A26" stroke-width="2.2" stroke-linecap="round"/>`,
		laurel: `
			<path d="M23 43 C12 41 6 31 8.5 15 M25 43 C36 41 42 31 39.5 15" fill="none" stroke="${O}" stroke-width="4.4" stroke-linecap="round"/>
			<path d="M23 43 C12 41 6 31 8.5 15 M25 43 C36 41 42 31 39.5 15" fill="none" stroke="#7E9A3A" stroke-width="2" stroke-linecap="round"/>
			<g fill="#9CC95A" ${s('stroke-width="1.8"')}>
				<ellipse cx="13" cy="15" rx="3" ry="5.5" transform="rotate(35 13 15)"/><ellipse cx="13.5" cy="23.5" rx="3" ry="5.5" transform="rotate(55 13.5 23.5)"/>
				<ellipse cx="16.5" cy="31.5" rx="3" ry="5.5" transform="rotate(70 16.5 31.5)"/><ellipse cx="6" cy="22" rx="2.6" ry="5" transform="rotate(-15 6 22)"/>
				<ellipse cx="35" cy="15" rx="3" ry="5.5" transform="rotate(-35 35 15)"/><ellipse cx="34.5" cy="23.5" rx="3" ry="5.5" transform="rotate(-55 34.5 23.5)"/>
				<ellipse cx="31.5" cy="31.5" rx="3" ry="5.5" transform="rotate(-70 31.5 31.5)"/><ellipse cx="42" cy="22" rx="2.6" ry="5" transform="rotate(15 42 22)"/>
			</g>
			<path d="M24 41 L21 46 M24 41 L27 46" stroke="#D9573F" stroke-width="2.4" stroke-linecap="round"/>`,
	};

	function svg(name, size) {
		const inner = icons[name];
		if (!inner) throw new Error("unknown icon " + name);
		const px = size ? ` width="${size}" height="${size}"` : "";
		return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"${px}>${inner}</svg>`;
	}

	const api = { icons, svg, names: Object.keys(icons) };
	if (typeof module !== "undefined") module.exports = api;
	else root.Icons = api;
})(this);
