'use strict';

const ethUtils = require('ethereumjs-utils');
const BladeIronClient = require('bladeiron_api'); // 11BE BladeIron Client API

// Helper functions, may go into bladeiron_api later
const toBool = (str) =>
{
        if (typeof(str) === 'boolean') return str;
        if (typeof(str) === 'undefined') return false;

        if (str.toLowerCase() === 'true') {
                return true
        } else {
                return false
        }
}

const mkdir_promise = (dirpath) =>
{
        const __mkdirp = (dirpath) => (resolve, reject) =>
        {
                mkdirp(dirpath, (err) => {
                        if (err) return reject(err);
                        resolve(true);
                })
        }

        return new Promise(__mkdirp(dirpath));
}

// Optract-specific RLP format
const fields =
[
   {name: 'nonce', length: 32, allowLess: true, default: new Buffer([]) },
   {name: 'optractAddress', length: 20, allowZero: false, default: new Buffer([]) },
   {name: 'originAddress', length: 20, allowZero: true, default: new Buffer([]) },
   {name: 'bidPrice', length: 32, allowLess: true, default: new Buffer([]) },
   {name: 'payload', length: 32, allowLess: true, default: new Buffer([]) },
   {name: 'v', allowZero: true, default: new Buffer([0x1c]) },
   {name: 'r', allowZero: true, length: 32, default: new Buffer([]) },
   {name: 's', allowZero: true, length: 32, default: new Buffer([]) }
];

class Optract extends BladeIronClient {
	constructor(rpcport, rpchost, options)
        {
		super(rpcport, rpchost, options);
	        this.ctrName = 'OptractRegistry';

                this.createOptract = (ethAmount, totalPrice, period) => 
		{
			return this.queryInitPrice().then((tokenAmount) => 
			{
                       		return this.manualGasBatch(2000000)(
					this.Tk('DAI')('approve')(this.ctrAddrBook['OptractRegistry'], tokenAmount)(),
                                        this.Tk(this.ctrName)('createOptract')(ethAmount, totalPrice, period)()
				).then((QID) => 
				{
					return this.getReceipts(QID).then((QIDlist) => { return {[QID]: QIDlist} });
                              	});
			});
                }

                this.queryInitPrice = () => { return this.call(this.ctrName)('queryInitPrice')() }

                this.isExpired = (optractAddr) => 
		{
                        return this.call(this.ctrName)('isExpired')(optractAddr).then((rc) => {return(rc)});
                }

                this.activeOptracts = (start, length, ownerAddr = '0x0') => 
		{
                        console.log("LOG: return arrays:");
                        console.log("     addr, expiretime (unix time in sec), total price of ETH (DAI), ETH amount, option price (DAI), filled(bool)");
                        return this.call(this.ctrName)('activeOptracts')(start, length, ownerAddr).then((rc) => {
                                return rc;
                        })
                }

                this.inactiveOptracts = (start, length, ownerAddr = '0x0') =>
		{
                        console.log("LOG: return arrays:");
                        console.log("     addr, expiretime (unix time in sec), total price of ETH (DAI), ETH amount, option price (DAI), filled(bool)");
                        return this.call(this.ctrName)('inactiveOptracts')(start, length, ownerAddr).then((rc) => {
                                return rc;
                        })
                }

                /*
                   below are optract related functions, assume already bind an optract by "app.Optract.connectABI()"
                */
                this.fillInEth = (ctrName) =>
                {
                        if (! ctrName in this.ctrAddrBook ) throw "contract not found";
                        return this.call(ctrName)('ethAmount')().then((ethAmount) => {
                                return this.sendTk(ctrName)('fillInEth')()(ethAmount);
                        })
                }

		this.putOnStock = (ctrName, optPrice) =>
		{
                        if (! ctrName in this.ctrAddrBook ) throw "contract not found";
			return this.call(ctrName)('queryOnStock')().then((rc) => {
				if (rc === true) { return false; }
				return this.sendTk(ctrName)('putOnStock')(optPrice)();	
			})
		}

                this.exercise = (ctrName) =>
                {
                        if (! ctrName in this.ctrAddrBook ) throw "contract not found";
                        return this.call(ctrName)('actionTime')().then((time) =>{
                                if (time - Math.floor(Date.now()/1000) < 600) {throw "too soon";}
                                return this.call(ctrName)('totalPriceInDai')().then((tokenAmount) => 
                                {
                                        return this.manualGasBatch(2000000)(
                                                this.Tk('DAI')('approve')(this.ctrAddrBook[ctrName], tokenAmount)(),
                                                this.Tk(ctrName)(currentOwnerExercise)()()
                                        ).then((QID) => 
                                        {
                                                return this.getReceipts(QID).then((QIDlist) => { return {[QID]: QIDlist} });
                                        });
                                });
                        }) 
                }

                this.claimOptract = (ctrName) =>
                {
                        if (! ctrName in this.ctrAddrBook ) throw "contract not found";
                        // todo: obtain proof, isLeft, targetLeat, merkleRoot
                        let [proof, isLeft, targetLeat, merkleRoot] = [[], [], '0x0', '0x0'];
                        return this.call(ctrName)('optionPrice')().then((tokenAmount) => {
                                return this.manualGasBatch(2000000)(
                                        this.Tk('DAI')('approve')(this.ctrAddrBook[ctrName], tokenAmount + tokenAmount/500)(),
                                        this.Tk(ctrName)('claimOptract')(proof, isLeft, targetLeat, merkleRoot)()
                                ).then((QID) =>
                                {
                                        return this.getReceipts(QID).then((QIDlist) => { return {[QID]: QIDlist} });
                                });
                        })
                }

		this.makeMerkleTreeAndUploadRoot = () =>
		{
			// Currently, we will group all block data into single JSON and publish it on IPFS
                        let blkObj =  {initHeight: this.initHeight, data: {} };
                        let leaves = [];

			Object.keys(this.bidRecords[blkObj.initHeight]).map((addr) => {
				if (this.winRecords[blkObj.initHeight][addr].length === 0) return;
			})
		}

		// Validator IPFS PubSub event handler
		this.handleValidate = (msgObj) =>
		{
			let address; 
			let optract; 
			let data = {};
                        let rlpx = Buffer.from(msgObj.msg.data);

			try {
				data = this.handleRLPx(fields)(rlpx); // decode
                                address = ethUtils.bufferToHex(data.originAddress);
                                optract = ethUtils.bufferToHex(data.optractAddress);
				if ( !('v' in data) || !('r' in data) || !('s' in data) ) { 
				  	return;
				} else if ( typeof(this.bidRecords[this.initHeight][address]) === 'undefined' ) {
                                     	this.bidRecords[this.initHeight][address] = [];
				  	return;
                                } else if ( this.bidRecords[this.initHeight][address].findIndex((x) => { return Buffer.compare(x.nonce, data.nonce) == 0 } ) !== -1) {
                                        console.log(`Duplicate nonce (${address}): received nonce ${ethUtils.bufferToInt(data.nonce)} more than once`);
                                        return;
                                } else if ( this.bidRecords[this.initHeight][address].findIndex((x) => { return Buffer.compare(x.payload, data.payload) == 0 } ) !== -1) {
                                        console.log(`Duplicate payload (${address}): ${ethUtils.bufferToHex(data.payload)}`)
                                        return;
				} else if ( this.bidRecords[this.initHeight][address].length === 100) { // limit to 100 bids per block for now to reduce loading
                                        console.log(`Max nonce reached (${address}): exceeds block limit of 100... ignored`);
                                        return;
                                }
			} catch(err) {
				console.trace(err);
				return;
			}

			return this.validPurchase(optract, address, ethUtils.bufferToInt(data.bidPrice)).then((rc) => {
				if (rc !== true) return;

				let sigout = {
                                        v: ethUtils.bufferToInt(data.v),
                                        r: data.r, s: data.s,
                                        originAddress: data.originAddress,
                                        payload: data.payload,
                                        netID: this.configs.networkID
                                };

				if (this.verifySignature(sigout)) {
                                        // store tx in mem pool for IPFS publish
                                        console.log(`---> Received winning claim from ${address}, Ticket: ${ethUtils.bufferToHex(data.ticket)}`);
                                        this.bidRecords[this.initHeight][address].push(data);
					// still need to determine what ACK message to send
                                        /*this.ipfs_pubsub_publish(
                                                this.channelACK,
                                                Buffer.from(ethUtils.bufferToInt(data.submitBlock) + '_' + address + '_' + ethUtils.bufferToHex(data.ticket))
                                        );*/ 
                                }
			})
		}

		// checking bid conditions
		this.validPurchase = (optract, buyer, bidPrice) => {
			let p = [
				this.myMemberStatus(buyer).then((rc) => { return rc[0] !== 'active'; }),
				this.call(this.ctrName)('totalOpts')().then((t) => { 
					return this.activeOptracts(1,t).then((a) => { 
						let idx = a[0].indexOf(optract);
						return idx !== -1 && a[5][idx] === true && bidPrice >= a[4][idx];
					}) 
				})
			];

			return Promise.all(p).then((rc) => {
				return rc.reduce((result, stat) => { return result && (stat === true) });
			})
		}

		// membership related
                this.memberStatus = (address) => {  // "status", "token (hex)", "since", "penalty"
                        return this.call('MemberShip')('getMemberInfo')(address).then( (res) => {
                                let status = res[0];
                                let statusDict = ["failed connection", "active", "expired", "not member"];
                                return [statusDict[status], res[1], res[2], res[3], res[4]]  // "status", "id", "since", "penalty", "kycid"
                        })
                }

        }
}

module.exports = Optract;
