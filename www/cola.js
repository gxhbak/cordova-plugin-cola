var exec = require('cordova/exec');

module.exports = {
	uuid: () => new Promise((resolve, reject) => exec(resolve, reject, 'Cola', 'uuid', [])),
	platform: () => new Promise((resolve, reject) => exec(resolve, reject, 'Cola', 'platform', [])),
	connect: (name, config) => new Promise((resolve, reject) => exec(resolve, reject, 'Cola', 'connect', [name, config])),
	disconnect: () => new Promise((resolve, reject) => exec(resolve, reject, 'Cola', 'disconnect', [])),
	getStatus: () => new Promise((resolve, reject) => exec(resolve, reject, 'Cola', 'getStatus', [])),
	onStatus: (resolve, reject) => exec(resolve, reject, 'Cola', 'onStatus', []) //回调
};