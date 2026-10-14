import { LightningElement, track } from 'lwc';
import savePartners from '@salesforce/apex/PartnerParserController.savePartners';

export default class PartnerParser extends LightningElement {
    @track htmlString = '';
    @track isProcessing = false;
    @track resultsList = [];

    handleTextChange(event) {
        this.htmlString = event.target.value;
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            const reader = new FileReader();
            reader.onload = (e) => {
                this.htmlString = e.target.result;
            };
            reader.readAsText(file);
        }
    }

    parseAndSave() {
        if (!this.htmlString) {
            return;
        }

        this.isProcessing = true;
        this.resultsList = []; 
        const parser = new DOMParser();
        const doc = parser.parseFromString(this.htmlString, 'text/html');
        
        const cards = doc.querySelectorAll('c-partner-card');
        let leadData = [];

        cards.forEach(card => {
            console.log('OUTPUT : ',"Reached here"+ this.htmlString+"\n\n"+card);
            try {
                // Listing URL and ID
                const linkEl = card.querySelector('a[href*="listingId="]');
                if (!linkEl) return; 
                
                const listingUrl = linkEl.href;
                const urlParams = new URL(listingUrl).searchParams;
                const listingId = urlParams.get('listingId');

                // Basic Info (Name field maps to the new 'Company Name' label)
                const name = card.querySelector('.pf-partner-card__name')?.getAttribute('title') || '';
                const logoUrl = card.querySelector('.pf-partner-card__logo')?.src || '';
                
                // HQ extracted safely from the H3 title attribute
                const hq = card.querySelector('h3')?.getAttribute('title') || '';

                // Description
                const descEl = card.querySelector('p.slds-text-body_small');
                const description = descEl ? descEl.getAttribute('title') || descEl.textContent.trim() : '';

                // Ratings and Reviews
                const ratingText = card.querySelector('.pf-ratingText')?.textContent || '0';
                const customerRating = parseFloat(ratingText);
                
                const reviewsText = card.querySelector('.pf-reviewText')?.textContent || '0';
                const customerReviews = parseInt(reviewsText.replace(/\D/g, ''), 10) || 0;
                
                // Badge
                const badgeEls = card.querySelectorAll('lightning-badge span[part="badge"]');
                let badgeList = [];
                badgeEls.forEach(b => {
                    const text = b.textContent.trim();
                    if (text) badgeList.push(text);
                });
                const badge = badgeList.join(', ');

                // Cloud Expert & Accredited
                let cloudExpert = '';
                let cloudAccredited = '';
                const popoverLabels = card.querySelectorAll('.pf-partner-card__popover-label strong');
                popoverLabels.forEach(label => {
                    const labelText = label.textContent.trim();
                    const valueEl = label.closest('p').nextElementSibling;
                    const valueText = valueEl ? valueEl.textContent.trim() : '';
                    
                    if (labelText.includes('Cloud Expert:')) {
                        cloudExpert = valueText;
                    } else if (labelText.includes('Cloud Accredited:')) {
                        cloudAccredited = valueText;
                    }
                });

                // Projects & Credentials
                let recentProjects = 0;
                let credentialedPeople = 0;
                const statLabels = card.querySelectorAll('p > strong');
                statLabels.forEach(label => {
                    const labelText = label.textContent.trim();
                    const valueEl = label.closest('p').nextElementSibling;
                    const exactValue = valueEl ? parseInt(valueEl.getAttribute('title') || '0', 10) : 0;

                    if (labelText.includes('Recent Projects:')) {
                        recentProjects = exactValue;
                    } else if (labelText.includes('Credentialed People:')) {
                        credentialedPeople = exactValue;
                    }
                });

                leadData.push({
                    sobjectType: 'Salesforce_Lead__c',
                    Listing_ID__c: listingId,
                    Listing_URL__c: listingUrl,
                    Name: name,
                    Logo_URL__c: logoUrl,
                    HQ_Location__c: hq,
                    Description__c: description,
                    Customer_Rating__c: customerRating,
                    Customer_Reviews__c: customerReviews,
                    Recent_Projects__c: recentProjects,
                    Credentialed_People__c: credentialedPeople,
                    Badge__c: badge,
                    Cloud_Expert__c: cloudExpert,
                    Cloud_Accredited__c: cloudAccredited
                });

            } catch (e) {
                console.error('Error parsing individual card:', e);
            }
        });

        if (leadData.length === 0) {
            this.isProcessing = false;
            return;
        }

        /* // --- Deduplicate records based on Listing_ID__c ---
        const uniqueLeadsMap = new Map();
        leadData.forEach(lead => {
            if (lead.Listing_ID__c) {
                uniqueLeadsMap.set(lead.Listing_ID__c, lead);
            }
        });
        const uniqueLeadData = Array.from(uniqueLeadsMap.values()); */

        // Send the payload to Apex
        savePartners({ recordsToUpsert: leadData })
            .then(result => {
                this.resultsList = result; 
                this.htmlString = ''; 
            })
            .catch(error => {
                console.error('Error saving partners', error);
            })
            .finally(() => {
                this.isProcessing = false;
            });
    }
}