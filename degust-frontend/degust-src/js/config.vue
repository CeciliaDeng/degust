<style src="../../node_modules/vue-multiselect/dist/vue-multiselect.min.css"></style>
<style>
    .options { border: 1px solid #aaa; border-radius: 5px; background-color: #eee; padding: 10px 3px; }

    .conditions { border: 1px solid #aaa; border-radius: 5px; padding: 0 3px; }

    .view { float: right; }
    .del-condition { float: right; }

    .init-select, .hidden-factor {margin-left: 15px; font-size: smaller;}
    .condition-up-down {display: inline-block; position: absolute;; width: 15px; height: 15px}
    .condition-up-down .glyphicon-triangle-top {position: absolute; top: 4px;}
    .condition-up-down .glyphicon-triangle-bottom {position: absolute; top: 20px;}
    .disabled {opacity: 0.5;}

    .col-name {width: 100%; margin-left: 16px; padding: 7px 0;}

    /* Hack to improve layout of multiselect */
    .conditions .multiselect__single {display: none;}

    .multiselect__option {padding: 5px; font-size: 12px; min-height: auto;}
    .multiselect__content-wrapper { border: thin solid black;}
    .multiselect--active {  z-index: 3; }  /* Make it above the slickgrid elements */

    .rep_used { padding: 0 3px; background-color: #ddd; border-radius: 3px; margin-left: 10px; float: right;}

    .fade-enter-active, .fade-leave-active { transition: opacity .5s }
    .fade-enter, .fade-leave-to  { opacity: 0  }


    #grid { height: 300px; font-size: 8pt; }

    #grid .slick-row { font-size: 8pt; }
    #grid >>> .slick-row:hover {
      font-weight: bold;
      color: #069;
    }

    #experimentDescription {
      resize: none;
      height: 37px;
      transition: all 0.4s;
    }

    #experimentDescription:focus {
      resize: none;
      height: 200px;
      transition: all 0.4s;
    }

    .flip-list-move {
        transition: transform 1s;
    }
</style>

<template>
    <div>
        <navbar :homeLink='"/"'
            :experimentName='settings.name'
            :fullSettings='settings'
            :extraMenuHtml='orig_settings["extra_menu_html"]'
            :uniqueCode='code'
            @showAbout='v => show_about = v'
            >
            <li slot="switchURL"><a class="view" v-bind:href="view_url">View</a></li>
        </navbar>

        <div class="container">
          <h1>Configuration</h1>

          <div class="row">
            <div class="col-md-12 options">
              <form class="form-horizontal">

              <div class="form-group">
                <label class="control-label col-sm-3" for="name">Name</label>
                <div class="controls col-sm-4">
                  <input v-model.trim='settings.name' class="form-control" type="text" name="name" placeholder="Unnamed" v-tooltip="tip('Optional: Give your experiment a name')" size='30' />
                </div>
              </div>

              <div class="form-group">
                  <label class="control-label col-sm-3">Input type</label>
                  <div class="controls col-sm-6"  v-tooltip="tip('Data type of the CSV file')">
                      <multiselect v-model="settings.input_type" :options='input_type_options' track-by='key' label='label' :allow-empty="false" :searchable="false" :close-on-select="true" :show-labels="false" placeholder="--- Required ---" />
                  </div>
              </div>

              <div class="form-group">
                <label class="control-label col-sm-3">Format type</label>

                <div class="controls col-sm-6">
                  <label class="radio">
                    <input v-model='settings.csv_format' v-bind:value=true type="radio">Comma separated (CSV)
                  </label>

                  <label class="radio">
                    <input v-model='settings.csv_format' v-bind:value=false type="radio">TAB separated (TSV)
                  </label>
                </div>
              </div>

              <div class="form-group">
                <label class="control-label col-sm-3">Info columns</label>
                <div class="controls col-sm-6"  v-tooltip="tip('Information columns to display in the gene table')">
                  <multiselect v-model="settings.info_columns" :options="column_names" :multiple="true" :close-on-select="false" :show-labels="false" :searchable="true" placeholder="Add column"/>
                </div>
              </div>

              <div class="form-group">
                <label class="control-label col-sm-3">Experiment Description</label>
                <div class="controls col-sm-6" >
                  <textarea class="form-control" v-model="settings.experimentDescription" type="text" placeholder="" id="experimentDescription" v-tooltip="tip('Brief Decription of Expriment')" size='30'/>
                </div>
              </div>

              <div v-show='is_rnaseq_counts'>
                <div class="form-group">
                  <label class="control-label col-sm-3" for="name">Min gene read count</label>
                  <div class="controls col-sm-1">
                    <input v-model.number='settings.min_counts' class="form-control" type="text" name="min-counts" placeholder="0" v-tooltip="tip('Optional: Minimum read count required in at least one replicate or the gene is ignored')" />
                  </div>
                </div>
                <div class="form-group">
                  <label class="control-label col-sm-3" for="name">Min gene CPM</label>
                  <div class="controls col-sm-1">
                    <input v-model.number='settings.min_cpm' class="form-control" type="text" name="min-cpm" placeholder="0" v-tooltip="tip('Optional: A gene must have at a CPM of at least this, in at least the number of specified samples')" />
                  </div>
                  <label class="control-label col-sm-2" for="name">in at least samples</label>
                  <div class="controls col-sm-1">
                    <input v-model.number='settings.min_cpm_samples' class="form-control" type="text" name="min-cpm" placeholder="0" v-tooltip="tip('Optional: A gene must have at a CPM of at least this, in at least the number of specified samples')" />
                  </div>
                </div>
              </div>

              <div v-show='is_maxquant'>
                <div class="form-group">
                  <label class="control-label col-sm-3" for="name">Min present columns</label>
                  <div class="controls col-sm-1">
                    <input v-model.number='settings.min_cpm' class="form-control" type="text" name="min-columnns" placeholder="0.8" v-tooltip="tip('Optional: Minumum percent of columns with values present to keep the protein')" />
                  </div>
                </div>
                <div class="form-group">
                  <label class="control-label col-sm-3" for="name">Min gene Intensity</label>
                  <div class="controls col-sm-1">
                    <input v-model.number='settings.min_counts' class="form-control" type="text" name="min-intensity" placeholder="0" v-tooltip="tip('Optional: A protein must have at an intensity of at least this, in at least the number of specified samples')" />
                  </div>
                  <label class="control-label col-sm-2" for="name">in at least samples</label>
                  <div class="controls col-sm-1">
                    <input v-model.number='settings.min_cpm_samples' class="form-control" type="text" name="min-intensity-samples" placeholder="0" v-tooltip="tip('Optional: A protein must have at an intensity of at least this, in at least the number of specified samples')" />
                  </div>
                </div>
              </div>

            <div v-show='is_rnaseq_counts || is_maxquant'>

                <div class="condition-group conditions">
                  <div class="form-group">
                    <span class="control-label col-sm-3">Condition name</span>
                    <span class="control-label col-sm-1">Replicates</span>
                  </div>

                  <div>
                      <transition-group name="flip-list" tag="div">
                          <div v-for='(rep,idx) in settings.replicates' :key='rep.id'
                               class="form-group condition">
                            <div class="controls col-sm-3">
                                <div class='condition-up-down'>
                                    <span @click='move_replicate(idx,-1)' :class='{disabled: idx==0}'
                                          class='glyphicon glyphicon-triangle-top'></span>
                                    <span @click='move_replicate(idx,1)' :class='{disabled: idx+1==settings.replicates.length}'
                                          class='glyphicon glyphicon-triangle-bottom'></span>
                                </div>
                                <input v-model='rep.name' class="control-label col-name" placeholder="Condition Name"/>
                            </div>
                            <div class="col-sm-9">
                              <div class="col-sm-8">
                                <multiselect v-model="rep.cols" :options="column_names"
                                             @input='selected_reps(rep)'
                                             :multiple="true" :close-on-select="false"
                                             :show-labels="false" :searchable="false"
                                             placeholder="Pick some"
                                             :tabindex=-1>
                                  <template slot="option" slot-scope="props">
                                    <div>{{props.option}}
                                        <span class='rep_used' v-for='cond in conditions_for_rep(props.option)'>{{cond}}</span>
                                    </div>
                                  </template>
                                </multiselect>
                              </div>
                              <div class="col-sm-4">
                                  <label class='init-select'>
                                      <input v-model='rep.init' type="checkbox" tabindex=-1 />Initial select
                                  </label>
                                  <label class='hidden-factor'>
                                      <input v-model='rep.factor' type="checkbox" tabindex=-1 />Hidden Factor
                                  </label>
                                  <button v-on:click='del_replicate(idx)' type="button" class="del-condition" tabindex=-1>&times;</button>
                              </div>
                            </div>
                          </div>
                      </transition-group>
                  </div>
                </div> <!-- conditions -->

                <div class='pull-right'> <!-- Editing of contrasts -->
                  <div>
                    <b v-if='settings.contrasts.length>0'>Contrasts:</b>
                    <button v-for='(contrast,idx) in settings.contrasts' class='btn btn-default'
                            @click.prevent='edit_contrast(idx)'>
                      {{contrast.name || 'Unnamed'}}
                    </button>
                    <button @click='add_contrast()' type="button" class="btn btn-primary" v-tooltip="tip('')">
                      Add contrast
                    </button>
                  </div>
                  <div v-if='editing_contrast!=null'>
                  <modal :showModal='true'>
                    <div slot='body'>
                      <contrasts :conditions='settings.replicates'
                                :edit='editing_contrast'
                                ref='contrast_editor'
                                />
                    </div>
                    <div slot='footer'>
                      <button class='btn btn-danger' @click.prevent='delete_contrast()'>Delete</button>
                      <button class='btn btn-primary' @click.prevent='close_contrast()'>Close</button>
                    </div>
                  </modal>
                  </div>
                </div>

                <div class="form-group">
                  <div class="col-sm-3">
                    <button v-on:click='add_replicate()' type="button" class="btn btn-primary" v-tooltip="tip('Add a new condition or treatment')">
                      Add condition
                    </button>
                  </div>
                </div>

              </div> <!-- 'is_rnaseq_counts || is_maxquant' -->

              <div v-show='is_pre_analysed'>
                <div class="form-group">
                  <label class="control-label col-sm-3" for="primary">Primary condition</label>
                  <div class="controls col-sm-3">
                    <input v-model='settings.primary_name' class="form-control" type="text" name="primary" placeholder="Primary" v-tooltip="tip('Name of the condition your fold-change data is relative to')" />
                  </div>
                </div>
                <div class="form-group">
                  <label class="control-label col-sm-3">FDR column</label>
                  <div class="controls col-sm-3">
                    <multiselect v-model="settings.fdr_column" :options="column_names" :allow-empty="true" :searchable="false" :close-on-select="true" :show-labels="false" placeholder="--- Required ---" v-tooltip="tip('Column containing the False-Discovery-Rate.  Sometimes called adj.P.Val')"></multiselect>
                    <span class='text-error'></span>
                  </div>
                </div>
                <div class="form-group">
                  <label class="control-label col-sm-3">Average expression column</label>
                  <div class="controls col-sm-3">
                    <multiselect v-model="settings.avg_column" :options="column_names" :allow-empty="true" :searchable="false" :close-on-select="true" :show-labels="false" placeholder="--- Required ---" v-tooltip="tip('Column containing the average (log) expression information.  Often called Amean or AveExpr')"></multiselect>
                    <span class='text-error'></span>
                  </div>
                </div>
                <div class="form-group">
                  <label class="control-label col-sm-3">Fold-change columns</label>
                  <div class="controls col-sm-3">
                    <multiselect v-model="settings.fc_columns" :options="column_names" :multiple="true" :close-on-select="false" :show-labels="false" :searchable="false" placeholder="Pick some" v-tooltip="tip('Columns containing the log fold-change data')"/>
                  </div>
                </div>
              </div>

              <button type='button' @click='advanced=!advanced'
                      class='btn btn-default btn-sm pull-right'>
                  Extra settings
              </button>
              <transition name="fade">
                  <div v-show='advanced'>
                      <div class='form-group'>
                        <label class='control-label col-sm-3'>Download Raw Data</label>
                        <div class="controls col-sm-3">
                          <button type="button" class="btn btn-info" v-on:click='download_raw' v-tooltip="tip('Download the dataset as raw a csv')">
                            Download
                          </button>
                        </div>
                      </div>

                      <div class="form-group">
                        <label class="control-label col-sm-3" for="config-locked">Config locked</label>
                        <div class="controls col-sm-1">
                          <input v-model='settings.config_locked' v-bind:disabled="!can_lock" class="form-control" type="checkbox" v-tooltip="tip('Lock the configuration page so only you can change it (you must be logged in)')" />
                        </div>
                      </div>

                      <div class="form-group">
                        <label class="control-label col-sm-3">Gene link column</label>
                        <div class="controls col-sm-3">
                          <multiselect v-model="settings.link_column" :options="column_names" :allow-empty="true" :searchable="false" :close-on-select="true" :show-labels="false" placeholder="--- Optional ---"></multiselect>
                        </div>
                      </div>
                      <div class="form-group">
                        <label class="control-label col-sm-3">Gene link URL</label>
                        <div class="controls col-sm-3">
                          <input v-model='settings.link_url' class="form-control" type="text" size='50' placeholder="Leave blank to have Degust guess" v-tooltip="tip('Optional: External link for genes.  Any %s in the link will be replaced by the defined link column')" />
                        </div>
                      </div>

                      <div v-if='!is_pre_analysed'>
                          <div class="form-group">
                            <label class="control-label col-sm-3">Default analysis</label>
                            <div class="controls col-sm-3">
                                <multiselect v-model="settings.dge_method" :options="dge_methods" track-by='value' label='label' :allow-empty="true" :searchable="false" :close-on-select="true" :show-labels="false" placeholder="--- Optional ---"></multiselect>
                            </div>
                          </div>
                          <div class="form-group">
                            <label class="control-label col-sm-3">Default FDR</label>
                            <div class="controls col-sm-3">
                                <input v-model.number='settings.fdrThreshold' class="form-control" type="text" placeholder="1" v-tooltip="tip('Optional: Default FDR threshold for display')" />
                            </div>
                          </div>
                      </div>

                      <div class='form-group'>
                        <label class='control-label col-sm-3'>Delete Dataset</label>
                        <div class="controls col-sm-3">
                          <button type="button" class="btn btn-danger" v-bind:disabled="!can_lock" @click='deleteDataset' v-tooltip="tip('Delete the current dataset')">
                            Delete
                          </button>
                        </div>
                      </div>

                  </div>
              </transition>

              <div class="form-group">
                <div class="col-sm-12">
                  <button v-on:click.prevent='save()' type="submit" class="btn btn-success">Save changes</button>
                  <button v-on:click.prevent='revert() 'type="button" class="btn btn-default">Revert</button>
                  <a v-bind:href="view_url" class="btn btn-default" v-tooltip="tip('View main page.  Note unsaved configuration will be lost')">View</a>
                </div>
              </div>
            </form>
            </div> <!-- options -->
          </div> <!-- row -->

          <div class="row">Number of columns = {{column_names.length}}</div>
          <slick-table id='grid'
                       :rows='asRows'
                       :columns='table_columns'
                       >
          </slick-table>
        </div> <!-- container -->

        <modal :showModal="modal.show" :closeAction="closeModal">
          <h1 slot="header">Saving settings</h1>
          <div slot="body">
              <div v-for='msg in modal.msgs' :class='modal.msgs_class'>
                  {{msg}}
              </div>
          </div>
          <div slot="footer">
            <button @click='closeModal' class="btn btn-default">Close</button>
            <a v-if="modal.view" v-bind:href="view_url" class="view btn btn-primary">View</a>
          </div>
        </modal>

        <!-- About box Modal -->
        <about :show='show_about' @close='show_about=false'></about>

        <deleteModal
                  :show='show_deleteModal'
                  @close='show_deleteModal=false'
                  @destroy='destroy'
                  >
        </deleteModal>

    </div>
</template>
<script lang='coffee' src="./config.coffee"></script>
