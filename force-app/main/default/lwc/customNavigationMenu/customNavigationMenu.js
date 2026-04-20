import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import isGuest from '@salesforce/user/isGuest';

// ★追加：Apexメソッドをインポート
import getBadgeCounts from '@salesforce/apex/CustomNavigationMenuController.getBadgeCounts';

export default class CustomNavigationMenu extends NavigationMixin(LightningElement) {
    @track currentPath = '';
    @track isMobileMenuOpen = false;
    
    // ★追加：取得したバッジの件数を保持する変数
    @track badgeCounts = {};

    get wrapperClass() {
        return this.isMobileMenuOpen ? 'global-header-wrapper mobile-open' : 'global-header-wrapper';
    }

    get mobileIcon() {
        return this.isMobileMenuOpen ? 'close' : 'menu';
    }

    get mobileLabel() {
        return this.isMobileMenuOpen ? '閉じる' : 'メニュー';
    }

    toggleMobileMenu() {
        this.isMobileMenuOpen = !this.isMobileMenuOpen;
    }

    connectedCallback() {
        this.currentPath = window.location.pathname;
    }

    @wire(CurrentPageReference)
    pageRef(reference) {
        if (reference) {
            setTimeout(() => {
                this.currentPath = window.location.pathname;
            }, 50);
        }
    }

    // ★追加：Apexからバッジの件数を取得
    @wire(getBadgeCounts)
    wiredBadgeCounts({ error, data }) {
        if (data) {
            this.badgeCounts = data;
        } else if (error) {
            console.error('Error fetching badge counts:', error);
        }
    }

    // ★変更：ダミーデータを削除し、ベースのメニュー構成に戻しました
    menuItems = [
        { id: 'home', label: 'ホーム', icon: 'home', path: '/' },
        { id: 'search', label: '求人を探す', icon: 'search', path: '/search' },
        { id: 'like', label: '気になる', icon: 'bookmark', path: '/like' },
        { id: 'process', label: '応募状況', icon: 'mail', path: '/process' },
        { id: 'condition', label: '登録情報', icon: 'account_circle', path: '/profile' }
    ];

    get processedMenuItems() {
        return this.menuItems.map(item => {
            let isActive = false;
            const current = this.currentPath.toLowerCase();

            if (item.id === 'home') {
                isActive = current === '/portal/s/' || 
                           current === '/portal/s' || 
                           current === '/portal/' || 
                           current === '/portal';
            } else {
                isActive = current.includes(item.path.toLowerCase());
            }

            // ★追加：取得した件数を対象メニューに割り当てる
            let count = 0;
            if (item.id === 'process' && this.badgeCounts.process) {
                count = this.badgeCounts.process;
            } else if (item.id === 'like' && this.badgeCounts.like) {
                count = this.badgeCounts.like;
            }

            // 99件を超える場合は「99+」と表示する
            let displayCount = count > 99 ? '99+' : count;

            return {
                ...item,
                className: isActive ? 'nav-item active' : 'nav-item',
                mobileClassName: isActive ? 'mobile-nav-item active' : 'mobile-nav-item',
                showBadge: count > 0,      // ★1件以上あればtrueになりバッジを表示
                badgeCount: displayCount   // ★表示する件数
            };
        });
    }

    handleNavigate(event) {
        event.preventDefault();
        const path = event.currentTarget.dataset.path;
        this.isMobileMenuOpen = false;
        
        this.currentPath = path === '/' ? '/portal/s/' : `/portal/s${path}`;

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: path
            }
        });
    }

    get isUserGuest() {
        return isGuest;
    }
}