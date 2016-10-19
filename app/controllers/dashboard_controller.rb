class DashboardController < ApplicationController

  before_filter :authorized?, :only => [:owner, :staging, :omeka, :startproject]
  before_filter :get_data, :only => [:owner, :staging, :omeka, :upload, :new_upload, :startproject]

  def authorized?
    unless user_signed_in? && current_user.owner
      redirect_to dashboard_path
    end
  end

  def dashboard_role
    if user_signed_in?
      if current_user.owner
        redirect_to dashboard_owner_path
      else
        redirect_to dashboard_watchlist_path
      end
    else
      redirect_to guest_dashboard_path
    end
  end

  def get_data
    @collections = current_user.collections
    @notes = current_user.notes
    @works = current_user.owner_works
    @ia_works = current_user.ia_works

    logger.debug("DEBUG: #{current_user.inspect}")
  end

  # Public Dashboard
  def index
    collections = Collection.all
    @document_sets = DocumentSet.all
    @collections = (collections + @document_sets).sort{|a,b| a.title <=> b.title }
  end

  # Owner Dashboard - start project
  def startproject
    @document_upload = DocumentUpload.new
    @document_upload.collection=@collection
    @omeka_items = OmekaItem.all
    @omeka_sites = current_user.omeka_sites
    @universe_collections = ScCollection.universe
    @sc_collections = ScCollection.all
  end

  # Owner Dashboard - list of works
  def owner
  end

  # Owner Dashboard - staging area
#  def staging
#  end

  # Owner Dashboard - omeka import
  def omeka
    @omeka_items = OmekaItem.all
    @omeka_sites = current_user.omeka_sites
  end

  # Owner Dashboard - upload document
  def upload
    @document_upload = DocumentUpload.new
  end

  def new_upload
    @document_upload = DocumentUpload.new(params[:document_upload])
    @document_upload.user = current_user

    if @document_upload.save
        if SMTP_ENABLED
          flash[:notice] = "Document has been uploaded and will be processed shortly. We'll email you at #{@document_upload.user.email} when ready."
          SystemMailer.new_upload(@document_upload).deliver!
        else
          flash[:notice] = "Document has been uploaded and will be processed shortly. Reload this page in a few minutes to see it."
        end
      @document_upload.submit_process
      ajax_redirect_to controller: 'collection', action: 'show', collection_id: @document_upload.collection.id
    else
      render action: 'upload'
    end
  end
  

  # Editor Dashboard - watchlist
  def watchlist
    @user = current_user
    collection_ids = Deed.where(:user_id => current_user.id).select(:collection_id).distinct.limit(5).map(&:collection_id)
    @collections = Collection.where(:id => collection_ids).order_by_recent_activity
    @page = recent_work
  end

  #Editor Dashboard - user with no activity watchlist
  def recent_work
    recent_deeds = Deed.where("work_id is not null AND collection_id not in (SELECT id FROM collections where restricted = 1) AND work_id not in (SELECT id FROM works where restrict_scribes = 1)").order('created_at desc').limit(10)
    @works = []
    #iterate through recent deeds to find works with blank pages
    recent_deeds.each do |d|
      recent = Work.find_by(id: d.work_id)
      if (recent != nil) && recent.pages.where("xml_text is null").any?
        @works << recent
      end
    end
    #find the first blank page in the most recently accessed work (as long as the works list isn't blank)
    unless @works.empty?
      recent_work = (Work.find_by(id: @works.first.id)).pages.where("xml_text is null").first
    #if the works list is blank, return nil
    else
      recent_work = nil
    end
  end

 # Editor Dashboard - activity
  def editor
    @user = current_user
  end

#Guest Dashboard - activity
  def guest
    @collections = Collection.limit(5).order_by_recent_activity
  end

end
