'use strict';

const ethUtils = require('ethereumjs-utils');
const EthTx    = require('ethereumjs-tx');
const BladeIronClient = require('bladeiron_api'); // 11BE BladeIron Client API
const xrange = require('xrange');
const AsciiTable = require('ascii-table');
const fs = require('fs');
const path = require('path');
const mkdirp = require('mkdirp');

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
   {name: 'optractAddress', length: 20, allowZero: true, default: new Buffer([]) },
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

		// IPFS pubsub stabilizer
		this.ipfsReconnect = (bootnode) => (peerlist) =>
		{
			return this.ipfsSwarmConnect(bootnode)
				   .then((rc) => { 
					  let p = peerlist.map((i) => { return this.client.call('ipfs_ping', [i]) });
					  return Promise.all(p).then((r) => { return {bootnode, peerlist, result: {SwarmConnect: rc, Ping: r} } })
				                        //.catch((err) => { console.log(`In Optract ipfsReconnect:`); console.trace(err); return {bootnode, peerlist, result: err} })
				   })
				   .catch((err) => { console.log(`In Optract ipfsReconnect:`); console.trace(err); return {bootnode, peerlist, result: err} })
		}

                this.createOptract = (ethAmount, totalPrice, period, optionPrice) =>
		{
                        return this.call(this.ctrName)('queryOptionMinPrice')().then((optionMinPrice) =>
			{
			        if (optionPrice < optionMinPrice) throw "optionPrice too low";
                       		return this.manualGasBatch(2000000)(
					this.Tk('DAI')('approve')(this.ctrAddrBook['OptractRegistry'], optionPrice)(),
                                        this.Tk(this.ctrName)('createOptract')(ethAmount, totalPrice, period, optionPrice)()
				).then((QID) => 
				{
					return this.getReceipts(QID).then((QIDlist) => { return {[QID]: QIDlist} });
                              	});
			});
                }

                this.queryOptionPrice = (ctrName) => { return this.call(ctrName)('queryOptionPrice')() }
                this.queryOptionMinPrice = () => { return this.call(this.ctrName)('queryOptionMinPrice')() }

                this.isExpired = (optractAddr) => 
		{
                        return this.call(this.ctrName)('isExpired')(optractAddr).then((rc) => {return(rc)});
                }

                this.activeOptracts = (start, length, ownerAddr = '0x0') => 
		{
                        //console.log("     addr, expiretime (unix time in sec), total price of ETH (DAI), ETH amount, option price (DAI), filled(bool)");
                        return this.call(this.ctrName)('activeOptracts')(start, length, ownerAddr).then((rc) => {
                                return rc;
                        })
                }

                this.inactiveOptracts = (start, length, ownerAddr = '0x0') =>
		{
                        //console.log("     addr, expiretime (unix time in sec), total price of ETH (DAI), ETH amount, option price (DAI), filled(bool)");
                        return this.call(this.ctrName)('inactiveOptracts')(start, length, ownerAddr).then((rc) => {
                                return rc;
                        })
                }

                /*
                   below are optract related functions, assume already bind an optract by "app.Optract.connectABI()"
                */
                this.fillInEth = (ctrName) =>
                {
                        if (! (ctrName in this.ctrAddrBook) ) throw "contract not found";
                        return this.call(ctrName)('ethAmount')().then((ethAmount) => {
                                return this.sendTk(ctrName)('fillInEth')()(ethAmount);
                        })
                }

		this.putOnStock = (ctrName, optPrice) =>
		{
                        if (! (ctrName in this.ctrAddrBook) ) throw "contract not found";
                        return this.call(ctrName)('currentOwner')().then((owner) => {
                                if (owner !== this.userWallet) throw `not your contract (owned by ${owner})`;
                                return this.call(ctrName)('queryOnStock')().then((rc) => {
                                        if (rc === true) { return false; }
                                        return this.sendTk(ctrName)('putOnStock')(optPrice)();
                                })
                        })
		}

                this.exercise = (ctrName) =>
                {
                        if (! (ctrName in this.ctrAddrBook) ) throw "contract not found";
                        // todo: be aware of expire time and know when can exercise
                        return this.call(ctrName)('currentOwner')().then((owner) => {
                                if (owner !== this.userWallet) throw `not your contract (owned by ${owner})`;
                                return this.call(ctrName)('actionTime')().then((time) =>{
                                        if (Math.floor(Date.now()/1000) - time < 900 ) {throw "too soon";}  // 900 = "sblockTimeStep" in Optract.sol
                                        return this.call(ctrName)('totalPriceInDai')().then((tokenAmount) =>
                                        {
                                                return this.manualGasBatch(2000000)(
                                                        this.Tk('DAI')('approve')(this.ctrAddrBook[ctrName], tokenAmount)(),
                                                        this.Tk(ctrName)('currentOwnerExercise')()()
                                                ).then((QID) =>
                                                {
                                                        return this.getReceipts(QID).then((QIDlist) => { return {[QID]: QIDlist} });
                                                });
                                        });
                                })
                        });
                }

                this.claimOptract = (ctrAddr) =>
                {
                        return this.connectABI('Optract', ctrAddr, ctrAddr).then(()=>{
                                let ctrName = 'Optract_' + ctrAddr;
                                return this.call('BlockRegistry')('getSblockNo')().then((blockNo) => {
                                        return this.call('BlockRegistry')('getBlockInfo')(blockNo - 1).then((plist) => {
                                                let mr = plist[1]; // block merkle root
                                                let bd = plist[2]; // IPFS hash of block
                                                if (mr !== '0x0' && bd !== '') {
                                                        this.validateMerkleProof(this.myClaims.claimHash, bd).then((rc) => {
                                                                let myClaimHash = this.myClaims.claimHash.toString('hex');
                                                                let args = [
                                                                    this.myClaims.proof,
                                                                    this.myClaims.isLeft,
                                                                    this.myClaims.targetLeaf,
                                                                    mr,
                                                                    this.myClaims.bidPrice
                                                                ];
                                                                if (rc) {
                                                                        console.log("* debug in claimOptract (proof, isLeft, targetLeaf, mr, bidPrice)");
                                                                        console.log(...args);
                                                                        return this.sendTk('DAI')('approve')(ctrAddr, this.myClaims.totalPrice)().then(()=>{
                                                                                return this.sendTk(ctrName)('claimOptract')(...args)()
                                                                                           .then((qid) => { return this.getReceipts(qid); })
                                                                                           .then((rx) => {
                                                                                                let tx = rx[0];
                                                                                                console.dir(tx);
                                                                                                if (tx.status !== '0x1') {
                                                                                                        throw "Claim Optract Failed!";
                                                                                                } else {
                                                                                                        console.log(`***** YOU GOT THE CONTRACT *****`);
                                                                                                        console.log(`MerkleRoot: ${mr}`);
                                                                                                        console.log(`BlockData (IPFS): ${bd}`);
                                                                                                        console.log(`ClaimHash: ${myClaimHash}`);
                                                                                                }
                                                                                           })
                                                                                           .catch((err) => { console.trace(err); return; });
                                                                        })
                                                                } else {
                                                                        console.log('Merkle Proof Process FAILED!!!!!!');
                                                                        console.log(`MerkleRoot: ${mr}`);
                                                                        console.log(`BlockData (IPFS): ${bd}`);
                                                                        console.log(`ClaimHash: ${myClaimHash}`);
                                                                }
                                                        })
                                                }
                                        })
                                })
                        })
                }

                this.validateMerkleProof = (targetLeaf, ipfsHash) => 
		{
			return this.loadPreviousLeaves(ipfsHash).then((leaves) => {
			        let results;
                                targetLeaf = ethUtils.bufferToHex(targetLeaf);
			        results = this.getMerkleProof(leaves, targetLeaf);
                                if (!results) {
                                        console.log('Warning! On-chain merkle validation will FAIL!!!');
                                        return false
                                }
			        let proof = results[0];
                                let isLeft = results[1];
                                let merkleRoot = results[2];
                                return this.call('BlockRegistry')('merkleTreeValidator')(proof, isLeft, targetLeaf, merkleRoot).then((rc) => {
                                        if (rc) {
                                                this.myClaims = { ...this.myClaims, proof:proof, isLeft:isLeft, targetLeaf:targetLeaf };
                                        } else {
                                                console.log('Warning! On-chain merkle validation will FAIL!!!');
                                        }
                                        return rc;
                                })
			})
			.catch((err) => { console.log(`ERROR in validateMerkleProof`); console.trace(err); return false; })
                }

		this.loadPreviousLeaves = (ipfsHash) => 
		{
			// load block data from IPFS
			// put them in leaves for merkleTree calculation
			return this.ipfsRead(ipfsHash).then((blockBuffer) => {
				let blockJSON = JSON.parse(blockBuffer.toString());

				if (Number(blockJSON.initHeight) !== Number(this.initHeight)) {
					console.log(`Oh No! Did not get IPFS data for ${this.initHeight}, got data for round ${blockJSON.initHeight} instead`);
					return [];
				}

				let leaves = [];
				Object.values(blockJSON.data).map((obj) => { return leaves = [ ...leaves, obj[0].payload ]; });

				return leaves;
			})
		}

		this.submitNewBid = (ctrAddr, bidPrice, overWriteNonce = null) =>
		{
		        if (typeof(this.channelName) === 'undefined') throw 'run app.Optract.start() first';
			let _nonce = overWriteNonce === null ? this.results[this.initHeight].length + 1 : overWriteNonce;
			let data = this.abi.encodeParameters(
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
			        this.myClaims.claimHash = _payload;
				return this.client.call('unlockAndSign', [this.userWallet, Buffer.from(data)]).then((sig) =>
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
					
					this.results[this.initHeight].push({...params, sent: false, rlp: rlp.serialize() });
				        this.myClaims.bidPrice = bidPrice;
                                        this.myClaims.totalPrice = bidPrice*1.002;  // 0.2% tx fee
					
					// IPFS_PUBSUB still needs to be added
					return this.sendClaims(this.initHeight, this.channelName);
				})
			})
		}

		this.sendClaims = (initHeight, channel) =>
                {
                        return this.results[initHeight].map((robj, idx) => {
                                if (!robj.sent) {
                                        return this.ipfs_pubsub_publish(channel, robj.rlp).then((rc) => {
                                                console.log(`- Signed message broadcasted: Nonce: ${robj.nonce}, Optract: ${robj.optractAddress}, Bid Price: ${robj.bidPrice}`);
						return rc;
                                        })
                                        .catch((err) => { console.log(`Error in sendClaims`); console.trace(err); return false});
                                }
                        })
                }

		this.sendHelper = (stats) =>
		{
			if (this.results[this.initHeight].length > 0) this.sendClaims(this.initHeight, this.channelName);
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

			/*console.log(`>>>>>>>>`);
                        console.log(`DEBUG: rlpObjs`); console.dir(rlpObjs);
                        console.log(`DEBUG: nclist`); console.dir(nclist);
                        console.log(`DEBUG: pldlist`); console.dir(pldlist);
			console.log(`<<<<<<<<`); */

                        rlpObjs.map((ro, idx) => {
                                if (ro[0] === nclist[idx-1]) { // overwrite previous tx with later one of same nonce
					rlplist[idx-1] = rlplist[idx];
					rlplist[idx] = null;
					pldlist[idx-1] = ro[5];
					pldlist[idx] = null;
				} else if (pldlist.indexOf(ro[5]) !== pldlist.lastIndexOf(ro[5])) { // remote duplicates
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
				if (this.bidRecords[blkObj.initHeight][addr].length === 0) return;
				
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
                                return this.sendTk('BlockRegistry')('submitMerkleRoot')(blkObj.initHeight, merkleRoot, rc[0].hash)();
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

		        console.log('debug::' + parseInt(data.toJSON()[4], 16));
			return this.validPurchase(optract, address, parseInt(data.toJSON()[4], 16)).then((rc) => {
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
				// this.memberStatus(buyer).then((rc) => { return rc[0] === 'active'; }),
                                this.memberStatus(buyer).then((rc) => { return true }),  // for debug
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

		// entrance functions
		//
		// For now, we simply initialize pubsub channels (and RAFT channel soon for validators!) and then:
		//  - buyer or seller will get CLI control back and they can start querying and trade
		//  - validator node will be controlled by a BOT routine.
		this.start = () => 
		{
			this.channelName = ethUtils.bufferToHex(ethUtils.sha256(this.ctrAddrBook[this.ctrName]));
			this.channelACK  = [ ...this.channelName ].reverse().join('');
			this.call('BlockRegistry')('getSblockNo')().then((rc) => { 
                                if (Number(rc) === 0) {
                                        throw "Error: failed to read side block number. Try it later.";
                                }
				this.initHeight = rc; 
			        console.log("current side block height: " + this.initHeight);
				this.results = {[this.initHeight]: []};
				this.myClaims = {};
			})
			
			return true;			
		}

		this.startValidate = () =>
		{
			this.channelName = ethUtils.bufferToHex(ethUtils.sha256(this.ctrAddrBook[this.ctrName]));
			this.channelACK  = [ ...this.channelName ].reverse().join('');
			return this.call('BlockRegistry')('getSblockNo')().then((rc) => { 
                                if (Number(rc) === 0) {
                                        throw "Error: failed to read side block number. Try it later.";
                                }
				this.initHeight = rc;
			        console.log("current side block height: " + this.initHeight);
				this.bidRecords = {[this.initHeight]: {}};
                        }).then(()=> {
			        return mkdir_promise(path.join(this.configs.database, String(this.initHeight)))
                        }).then(()=> {
			        return this.ipfs_pubsub_subscribe(this.channelName)(this.handleValidate);	
                        })
		}

		this.manualSettle = () =>
		{
			return this.call('BlockRegistry')('getSblockNo')().then((height) => { 
			    this.initHeight = height;
                            return this.ipfs_pubsub_unsubscribe(this.channelName).then((rc) => {
                                    return this.makeMerkleTreeAndUploadRoot();
                            })
                            .then((QID) =>
                            {
                                    this.startValidate();  // for next sblockNo
                                    return this.getReceipts(QID).then((QIDlist) => { return {[QID]: QIDlist} });
                            });
                        })
		}

		// high-level utilities
		this.orderList = (start, end) => {
			let header = ['Optract Addr', 'Expire Time', 'Total Value (DAI)', 'ETH Amount', 'Optract Price (DAI)', 'Filled (bool)'];
			let holder = ['N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A'];
			return this.activeOptracts(start,end).then((raw) => {
				let len = raw[0].length; 
				let xr  = xrange(0, len).toArray();
				let out = xr.map((i) => { return [] }); 

				raw.map((j) => { 
					xr.map((f) => { out[f] = [ ...out[f], j[f] ] });
				});
				
				let table = new AsciiTable('Optract Active Orders');
				table.setHeading(...header);

                                if (out.length > 0) {
					out.map((o) => { o[1] = (new Date(o[1]*1000)).toString(); table.addRow(...o) });
					// out.map((o) => { console.log(o[1]);table.addRow(...o) });
				} else {
					table.addRow(...holder);
				}
				
				console.log(table.toString());
				return 	
			})
		}	
	
		this.inactiveList = (start, end) => {
			let header = ['Optract Addr', 'Expire Time', 'Total Value (DAI)', 'ETH Amount', 'Optract Price (DAI)', 'Filled (bool)'];
			let holder = ['N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A'];
			return this.inactiveOptracts(start,end).then((raw) => {
				let len = raw[0].length; 
				let xr  = xrange(0, len).toArray();
				let out = xr.map((i) => { return [] }); 

				raw.map((j) => { 
					xr.map((f) => { out[f] = [ ...out[f], j[f] ] });
				});
				
				let table = new AsciiTable('Optract Inactive Orders');
				table.setHeading(...header);

				if (out.length > 0) {
					out.map((o) => { o[1] = (new Date(o[1]*1000)).toString(); table.addRow(...o) });
				} else {
					table.addRow(...holder);
				}
				console.log(table.toString());
				return 	
			})
		}		
        }
}

module.exports = Optract;
