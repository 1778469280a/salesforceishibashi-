import { LightningElement } from 'lwc';
import runCandiDataBatch from "@salesforce/apex/BatchLauncher.runCandiDataBatch";

export default class RunBatch extends LightningElement {
    handleRunCandiDataBatch() {
        runCandiDataBatch()
            .then(() => {
                console.log('CandiDataBatch has been executed successfully.');
            })
            .catch(error => {
                console.error('Error executing CandiDataBatch:', error);
            });
    }
}