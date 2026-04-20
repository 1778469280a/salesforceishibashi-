import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class Sendmail extends NavigationMixin(LightningElement) {
    isNewUser = false;
    isExistingUser = false;

    connectedCallback() {
        const type = sessionStorage.getItem('type');
        sessionStorage.removeItem('type');

        this.isNewUser = type === 'NewUser';
        this.isExistingUser = type === 'ExistingUser';

        if (!this.isNewUser && !this.isExistingUser) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url: '/login' }
            });
        }
    }

    handleBackToTop() {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'home'
            }
        });
    }
}