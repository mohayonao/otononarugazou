fs       = require 'fs'
express  = require 'express'
mongoose = require 'mongoose'

app = module.exports = express.createServer()

app.configure ->
    mongo_url = process.env.MONGOHQ_URL or 'mongodb://localhost/otononarugazou'
    app.use express.bodyParser()
    app.use express.methodOverride()
    app.use app.router
    app.use express.static("#{__dirname}/static")
    mongoose.connect mongo_url

app.configure 'development', ->
    app.use express.errorHandler(dumpExceptions:true, showStack:true)

app.configure 'production', ->
    app.use express.errorHandler()

Gazou = mongoose.model 'Gazou', new mongoose.Schema(buffer: Buffer)

app.post '/upload', (req, res)->
    unless req.files.file
        return res.send 'error', 404
    unless req.files.file.mime is 'image/png'
        return res.send 'error', 404
    filepath = req.files.file.path
    fs.readFile filepath, (err, buffer)->
        gazou = new Gazou(buffer:buffer)
        gazou.save (err)-> res.send gazou._id

app.get '/list', (req, res)->
    Gazou.find().sort('-_id').limit(12).exec (err, list)->
        unless list then list = []
        res.setHeader 'Content-Type', 'application/json'
        res.send JSON.stringify list.map (x)-> x._id

app.get '/get_upload_url', (req, res)->
    res.send '/upload'

app.get '/:gazou_id?', (req, res)->
    matches = /([0-9a-f]+)\.png/.exec req.params.gazou_id
    if matches
        gazou_id = matches[1]
        Gazou.findOne {_id:gazou_id}, (err, gazou)->
            if gazou
                res.setHeader 'Content-Type', 'image/png'
                res.setHeader 'Cache-Control', 'private, max-age=604800'
                res.send gazou.buffer
            else
                res.send 'Not Found', 404
    else
        res.sendfile "#{__dirname}/static/html/index.html"

app.listen process.env.PORT or 3000
