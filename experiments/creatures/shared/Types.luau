--!strict
export type Animation = { rig: string, action: string, loop: boolean }
export type Feature = {
	id: string,
	kind: string,
	socket: string,
	offset: { number },
	scale: { number },
	material: string,
}
export type BoneSpec = { name: string, parent: string?, position: { number } }
export type Socket = { bone: string, position: { number } }
export type Rig = { id: string, bones: { BoneSpec }, sockets: { [string]: Socket } }
export type Form = {
	rig: string,
	generator: string,
	source: string?,
	size: { number },
	headScale: number,
	eyeSpacing: number,
	features: { Feature },
	animations: { [string]: Animation },
}
export type Profile = {
	enabled: boolean,
	duration: number,
	spinTurnsPerSecond: number,
	transitionFraction: number,
	revealFraction: number,
	effectColor: { number },
	effect: string,
}
export type Species = {
	id: string,
	placeholder: boolean,
	palette: { [string]: { number } },
	pattern: string,
	forms: { [string]: Form },
	transformation: Profile,
}
export type Sample = {
	stage: string,
	progress: number,
	transformed: boolean,
	spin: number,
	squash: number,
	energy: number,
	reveal: number,
}
return {}
