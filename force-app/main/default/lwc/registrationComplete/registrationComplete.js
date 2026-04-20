import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class RegistrationComplete extends NavigationMixin(LightningElement) {
    handleLogin() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/login'
            }
        });
    }
}