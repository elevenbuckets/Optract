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
   {name: 'submitBlock', length: 32, allowLess: true, default: new Buffer([]) },
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

		this.submitNewBid = (ctrAddr, bidPrice, overWriteNonce = null) =>
		{
			let _nonce = overWriteNonce === null ? this.results[this.initHeight].length + 1 : overWriteNonce;
			let data = abi.encodeParameters(
				[ 'uint', 'address', 'address', 'uint' ],
				[ _nonce, ctrAddr, this.userWallet, bidPrice ]
			);

			let p = [
				this.client.call('ethNetStatus'),
				this.validPurchase(ctrAddr, this.userWallet, bidPrice)
			];

			return Promise.all(p).then((rc) => 
			{
				if (!rc[1]) return false;
				let _payload = ethUtils.hashPersonalMessage(Buffer.from(data));
				this.client.call('unlockAndSign', [this.userWallet, Buffer.from(data)]).then((sig) =>
                                {
					let v = Number(sig.v);
                                        let r = Buffer.from(sig.r);
                                        let s = Buffer.from(sig.s);

					let params = 
					{
						nonce: _nonce,
						optractAddress: ctrAddr,
						originAddress: this.userWallet,
						submitBlock: rc[0].blockHeight,
						bidPrice,
						payload: _payload,
						v,r,s
					};

					let rlp = this.handleRLPx(fields)(params); // encode
					
					this.result[this.initHeight].push({...params, sent: false, rlp});
					
					// IPFS_PUBSUB still needs to be added
					this.sendClaims(this.initHeight, this.channelName);
				})
			})
		}

		this.sendClaims = (initHeight, channel) =>
                {
                        this.results[initHeight].map((robj, idx) => {
                                if (!robj.sent) {
                                        return this.ipfs_pubsub_publish(channel, robj.rlp.serialize()).then((rc) => {
                                                console.log(`- Signed message broadcasted: Optract: ${robj.optractAddress}, Payload: ${robj.payload}`);
                                        })
                                        .catch((err) => { console.log(`Error in sendClaims`); console.trace(err); return false});
                                }
                        })
                }

		// for current round by validator only
                this.generateBlock = (blkObj) =>
                {
                        const __genBlockBlob = (blkObj) => (resolve, reject) =>
                        {
                                fs.writeFile(path.join(this.configs.database, String(blkObj.initHeight), 'blockBlob'), JSON.stringify(blkObj), (err) => {
                                        if (err) return reject(err);
                                        resolve(path.join(this.configs.database, String(blkObj.initHeight), 'blockBlob'));
                                })
                        }

                        let stage = new Promise(__genBlockBlob(blkObj));
                        stage = stage.then((blockBlobPath) =>
                        {
                                console.log(`Local block data cache: ${blockBlobPath}`);
                                return this.ipfsPut(blockBlobPath);
                        })
                        .catch((err) => { console.log(`ERROR in generateBlock`); console.trace(err); });

                        return stage;
                }

		this.uniqRLP = (address) => 
		{
			const compare = (a,b) => { if (ethUtils.bufferToInt(a.nonce) > ethUtils.bufferToInt(b.nonce)) { return 1 } else { return -1 }; return 0 };

			let pldlist = []; let nclist = [];
                        let rlplist = this.bidRecords[this.initHeight][address].sort(compare).slice(0, 100);

                        let rlpObjs = rlplist.map((r) => {
                                nclist.push(r.toJSON()[0]); // nonce
                                pldlist.push(r.toJSON()[5]); // payload
                                return r.toJSON();
                        });

			console.log(`>>>>>>>>`);
                        console.log(`DEBUG: rlpObjs`); console.dir(rlpObjs);
                        console.log(`DEBUG: nclist`); console.dir(nclist);
                        console.log(`DEBUG: pldlist`); console.dir(pldlist);
			console.log(`<<<<<<<<`);

                        rlpObjs.map((ro, idx) => {
                                if (ro[0] === nclist[idx-1]) {
					rlplist[idx-1] = rlplist[idx];
					rlplist[idx] = null;
					pldlist[idx-1] = ro[5];
					pldlist[idx] = null;
				} else if (pldlist.indexOf(ro[5]) !== pldlist.lastIndexOf(rc[5])) {
                                        rlplist[idx] = null;
					pldlist[idx] = null;
                                }
                        })

                        return {data: rlplist.filter((x) => { return x !== null }), leaves: pldlist.filter((x) => { return x !== null })};
		}

		this.makeMerkleTreeAndUploadRoot = () =>
		{
			// Currently, we will group all block data into single JSON and publish it on IPFS
                        let blkObj =  {initHeight: this.initHeight, data: {} };
                        let leaves = [];

			// is this block data structure good enough?
			Object.keys(this.bidRecords[blkObj.initHeight]).map((addr) => {
				if (this.winRecords[blkObj.initHeight][addr].length === 0) return;
				
				let out = this.uniqRLP(addr);
				blkObj.data[addr] = out.data;
				leaves = [ ...leaves, ...out.leaves ];
			});

                        console.log(`DEBUG: Final Leaves for initHeight = ${blkObj.initHeight}:`); console.dir(leaves);

			let merkleTree = this.makeMerkleTree(leaves);
                        let merkleRoot = ethUtils.bufferToHex(merkleTree.getMerkleRoot());
                        console.log(`Block Merkle Root: ${merkleRoot}`);

                        let stage = this.generateBlock(blkObj);
                        stage = stage.then((rc) => {
                                console.log('IPFS Put Results'); console.dir(rc);
                                return this.sendTk(this.ctrName)('submitMerkleRoot')(blkObj.initHeight, merkleRoot, rc[0].hash)();
                        })
                        .catch((err) => { console.log(`ERROR in makeMerkleTreeAndUploadRoot`); console.trace(err); });

                        return stage;
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
                               // } else if ( this.bidRecords[this.initHeight][address].findIndex((x) => { return Buffer.compare(x.nonce, data.nonce) == 0 } ) !== -1) {
                               //         console.log(`Duplicate nonce (${address}): received nonce ${ethUtils.bufferToInt(data.nonce)} more than once`);
                               //         return;
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
                                        console.log(`---> Received bid from ${address}, target Optract: ${optract}}`);
                                        this.bidRecords[this.initHeight][address].push(data);
                                        this.ipfs_pubsub_publish(
                                                this.channelACK,
                                                Buffer.from(ethUtils.bufferToInt(data.submitBlock) + '_' + address + '_' + ethUtils.bufferToHex(data.payload))
                                        ); 
                                }
			})
		}

		// checking bid conditions
		this.validPurchase = (optract, buyer, bidPrice) => {
			let p = [
				//this.myMemberStatus(buyer).then((rc) => { return rc[0] !== 'active'; }),
				this.call(this.ctrName)('queryOptractRecords')(optract).then((rc) => { 
					let t = rc[0]; 
					return this.activeOptracts(t,t).then((a) => { 
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
